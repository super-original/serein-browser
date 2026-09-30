import Foundation

public enum NativeMessageFramingError:LocalizedError {
    case invalidLength,invalidJSON,truncatedMessage
    public var errorDescription:String? {
        switch self {
        case .invalidLength:return "The native host message exceeds the permitted size or has an empty body."
        case .invalidJSON:return "The native host did not send valid UTF-8 JSON."
        case .truncatedMessage:return "The native host closed its output during a message."
        }
    }
}

/// Native messaging uses native-endian UInt32 lengths. All supported Serein
/// architectures are little-endian ARM64. This codec grants no native access.
public enum NativeMessageFraming {
    public static let maximumHostMessage=1024*1024
    public static let maximumChromeRequest=64*1024*1024
    public static func encode(_ value:Any,maximumBytes:Int=maximumChromeRequest) throws -> Data {
        let payload:Data
        do {payload=try JSONSerialization.data(withJSONObject:value,options:[.fragmentsAllowed,.sortedKeys])}
        catch {throw NativeMessageFramingError.invalidJSON}
        guard !payload.isEmpty,payload.count<=maximumBytes,payload.count<=Int(UInt32.max) else{throw NativeMessageFramingError.invalidLength}
        var length=UInt32(payload.count).littleEndian
        var result=withUnsafeBytes(of:&length){Data($0)}
        result.append(payload);return result
    }
}

/// Incrementally consumes fragmented or coalesced messages without trusting the
/// announced length. Only one bounded partial message is buffered at a time.
public struct NativeMessageDecoder:Sendable {
    private var header=Data()
    private var payload=Data()
    private var expected:Int?
    private var failed=false
    public init(){}
    public mutating func append(_ chunk:Data) throws -> [Data] {
        guard !failed else{throw NativeMessageFramingError.invalidJSON}
        do {
            var cursor=chunk.startIndex
            var messages:[Data]=[]
            while cursor<chunk.endIndex {
                if expected==nil {
                    let count=min(4-header.count,chunk.distance(from:cursor,to:chunk.endIndex))
                    let end=chunk.index(cursor,offsetBy:count)
                    header.append(chunk[cursor..<end]);cursor=end
                    guard header.count==4 else{continue}
                    let bytes=Array(header)
                    let length=Int(bytes[0]) | Int(bytes[1])<<8 | Int(bytes[2])<<16 | Int(bytes[3])<<24
                    guard length>0,length<=NativeMessageFraming.maximumHostMessage else{throw NativeMessageFramingError.invalidLength}
                    expected=length;header.removeAll(keepingCapacity:true)
                }
                guard let expected else{continue}
                let count=min(expected-payload.count,chunk.distance(from:cursor,to:chunk.endIndex))
                let end=chunk.index(cursor,offsetBy:count)
                payload.append(chunk[cursor..<end]);cursor=end
                if payload.count==expected {
                    guard String(data:payload,encoding:.utf8) != nil,
                          (try? JSONSerialization.jsonObject(with:payload,options:.fragmentsAllowed)) != nil else{throw NativeMessageFramingError.invalidJSON}
                    messages.append(payload);payload=Data();self.expected=nil
                }
            }
            return messages
        } catch {failed=true;header=Data();payload=Data();expected=nil;throw error}
    }
    public func finish() throws {
        guard !failed else{throw NativeMessageFramingError.invalidJSON}
        guard header.isEmpty,expected==nil,payload.isEmpty else{throw NativeMessageFramingError.truncatedMessage}
    }
}
