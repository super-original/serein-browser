import Foundation

public enum DownloadPhase: String, Codable, Sendable {
    case choosing, downloading, cancelling, paused, complete, failed, cancelled, interrupted
    public var isActive: Bool {self == .choosing || self == .downloading || self == .cancelling}
    public var isFinished: Bool {!isActive && self != .paused}
}
public struct DownloadRecord: Identifiable, Codable, Sendable {
    public var id: UUID
    public var name: String
    public var source: URL?
    public var destination: URL?
    public var phase: DownloadPhase
    public var detail: String
    public var created: Date
    public var privateWindowID: UUID?
    public private(set) var finalURL: URL?
    public var mimeType: String?
    public var expectedBytes: Int64?
    public var receivedBytes: Int64?
    public var completed: Date?
    public init(id:UUID=UUID(),name:String="Download",source:URL?=nil,destination:URL?=nil,phase:DownloadPhase = .choosing,detail:String="",privateWindowID:UUID?=nil) {
        self.id=id;self.name=name;self.destination=destination;self.phase=phase;self.detail=detail;self.privateWindowID=privateWindowID;created=Date()
        self.source=Self.redacted(source)
    }
    private static func redacted(_ url:URL?)->URL? {
        guard let url,var parts=URLComponents(url:url,resolvingAgainstBaseURL:false) else{return nil}
        parts.user=nil;parts.password=nil;parts.fragment=nil;return parts.url
    }
    public mutating func receivedResponse(url:URL?,mimeType:String?,expectedBytes:Int64) {
        finalURL=Self.redacted(url);self.mimeType=mimeType
        self.expectedBytes=expectedBytes>=0 ? expectedBytes : nil
    }
    public static func encodedHistory(_ records:[DownloadRecord]) throws -> Data {
        try JSONEncoder().encode(records.filter{$0.privateWindowID == nil})
    }
    public static func restoredHistory(_ data:Data) throws -> [DownloadRecord] {
        try JSONDecoder().decode([DownloadRecord].self,from:data).filter{$0.privateWindowID == nil}.map {
            var record=$0
            if record.phase.isActive || record.phase == .paused {record.phase = .interrupted;record.detail="Interrupted when Serein closed. No saved resume data is available."}
            return record
        }
    }
}
