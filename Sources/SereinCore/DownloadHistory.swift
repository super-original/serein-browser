import Foundation

/// The high-water mark and normal records share one atomic file. Clearing all
/// visible records must not allow a later download to reuse an old identifier.
public struct DownloadHistory:Codable,Sendable {
    public static let maximumIdentifier:Int64=9_007_199_254_740_991
    public private(set) var version=1
    public private(set) var nextIdentifier:Int64=1
    public var records:[DownloadRecord]=[]
    public init() {}
    public enum Failure:Error {case unsupportedVersion,invalidIdentifiers,exhausted,oversized}
    public mutating func allocate() throws->Int64 {
        guard nextIdentifier>0,nextIdentifier<=Self.maximumIdentifier else{throw Failure.exhausted}
        let value=nextIdentifier;nextIdentifier+=1;return value
    }
    private func validate() throws {
        guard version==1 else{throw Failure.unsupportedVersion}
        guard (1...(Self.maximumIdentifier+1)).contains(nextIdentifier) else{throw Failure.invalidIdentifiers}
        var used=Set<Int64>(),recordsSeen=Set<UUID>()
        for record in records where record.privateWindowID==nil {
            guard let id=record.browserIdentifier,id>0,id<nextIdentifier,id<=Self.maximumIdentifier,used.insert(id).inserted,recordsSeen.insert(record.id).inserted else{throw Failure.invalidIdentifiers}
        }
    }
    public func encoded(records:[DownloadRecord]) throws->Data {
        var value=self;value.records=records.filter{$0.privateWindowID==nil}
        try value.validate()
        let data=try JSONEncoder().encode(value)
        guard data.count<=32*1024*1024 else{throw Failure.oversized}
        return data
    }
    public static func decode(_ data:Data) throws->(history:Self,migrated:Bool) {
        guard data.count<=32*1024*1024 else{throw Failure.oversized}
        var result:Self
        let migrated:Bool
        if let legacy=try? JSONDecoder().decode([DownloadRecord].self,from:data) {
            result=Self();migrated=true
            for var record in legacy where record.privateWindowID==nil {
                // Legacy files predate numeric IDs; do not trust an injected one.
                record.browserIdentifier=try result.allocate();result.records.append(record)
            }
        } else {
            result=try JSONDecoder().decode(Self.self,from:data);migrated=false
            result.records.removeAll{$0.privateWindowID != nil}
        }
        try result.validate()
        result.records=result.records.map {record in
            var value=record
            if value.phase.isActive || value.phase == .paused {value.phase = .interrupted;value.detail="Interrupted when Serein closed. No saved resume data is available."}
            return value
        }
        return (result,migrated)
    }
}
