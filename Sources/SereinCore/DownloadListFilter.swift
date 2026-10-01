import Foundation

/// Native library filtering. This is not the WebExtensions DownloadQuery contract.
public enum DownloadListFilter:String,CaseIterable,Sendable {
    case all,active,paused,complete,stopped
    public var title:String {
        switch self {case .all:"All";case .active:"Active";case .paused:"Paused";case .complete:"Complete";case .stopped:"Stopped"}
    }
    public func includes(_ record:DownloadRecord)->Bool {
        switch self {
        case .all:true
        case .active:record.phase.isActive
        case .paused:record.phase == .paused
        case .complete:record.phase == .complete
        case .stopped:[.failed,.cancelled,.interrupted].contains(record.phase)
        }
    }
}
extension DownloadRecord {
    public func matchesSearch(_ text:String)->Bool {
        let query=text.trimmingCharacters(in:.whitespacesAndNewlines)
        guard !query.isEmpty else{return true}
        return [name,source?.absoluteString,finalURL?.absoluteString,destination?.lastPathComponent].compactMap{$0}.contains{$0.localizedCaseInsensitiveContains(query)}
    }
}
