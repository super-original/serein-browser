import Foundation
import CryptoKit

/// Opaque public WebKit state is only reusable with an exact engine/OS identity.
/// It can contain page/form data; saving it requires an explicit user preference.
public struct SavedNavigationHistory:Codable,Sendable {
    public let windowID:UUID
    public let tabID:UUID
    public let url:String
    public let engine:String
    public let state:Data
    public let checksum:String
    public init(windowID:UUID,tabID:UUID,url:String,engine:String,state:Data) {
        self.windowID=windowID;self.tabID=tabID;self.url=url;self.engine=engine;self.state=state;checksum=SHA256.hash(data:state).map{String(format:"%02x",$0)}.joined()
    }
    static func validated(_ records:[Self],windows:[BrowserWindowState])->[Self]? {
        var result:[Self]=[],bytes=0,seen=Set<UUID>()
        for record in records.prefix(128) {
            guard !record.engine.isEmpty,record.engine.utf8.count<=512,
                  !record.state.isEmpty,record.state.count<=2*1024*1024,
                  bytes+record.state.count<=16*1024*1024,
                  record.checksum==SHA256.hash(data:record.state).map{String(format:"%02x",$0)}.joined(),
                  StoredPageURL.webHistoryURL(record.url)==record.url,
                  let window=windows.first(where:{$0.id==record.windowID && !$0.isPrivate}),
                  window.tabs.contains(where:{$0.id==record.tabID && $0.url==record.url}),
                  seen.insert(record.tabID).inserted else{continue}
            result.append(record);bytes+=record.state.count
        }
        return result.isEmpty ? nil : result
    }
}
