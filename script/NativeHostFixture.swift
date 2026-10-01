import Foundation

// Controlled test executable: echoes framed JSON and the caller origin. It
// reads no files, makes no network requests and launches no child programs.
func exact(_ count:Int)->Data? {
    var result=Data()
    while result.count<count {
        let next=FileHandle.standardInput.readData(ofLength:count-result.count)
        if next.isEmpty{return nil};result.append(next)
    }
    return result
}
while let header=exact(4) {
    let b=Array(header),count=Int(b[0]) | Int(b[1])<<8 | Int(b[2])<<16 | Int(b[3])<<24
    guard count>0,count<=1024*1024,let data=exact(count),let object=try? JSONSerialization.jsonObject(with:data,options:.fragmentsAllowed) else{exit(2)}
    let response:[String:Any]=["echo":object,"origin":CommandLine.arguments.dropFirst().first ?? "","pid":ProcessInfo.processInfo.processIdentifier]
    guard let payload=try? JSONSerialization.data(withJSONObject:response,options:.sortedKeys) else{exit(3)}
    var size=UInt32(payload.count).littleEndian
    FileHandle.standardOutput.write(withUnsafeBytes(of:&size){Data($0)})
    FileHandle.standardOutput.write(payload)
}
