import AppKit

@MainActor enum FindVerification {
    static func run(session:BrowserSession) async -> [RuntimeVerification.Result] {
        var results:[RuntimeVerification.Result]=[]
        func check(_ name:String,_ passed:Bool){results.append(.init(name:name,passed:passed,detail:"Public WKWebView.find against the deterministic fixture"))}
        func search(_ query:String,backwards:Bool=false) async -> Bool? {
            session.findText=query
            return await withCheckedContinuation {continuation in
                session.find(backwards:backwards){continuation.resume(returning:$0)}
            }
        }
        session.findVisible=true
        check("find-missing-query",await search("serein-absent-find-token")==false && session.findResult=="No matches")
        check("find-existing-query",await search("Workspaces")==true && session.findResult.isEmpty)
        check("find-backwards-wrap",await search("Workspaces",backwards:true)==true)
        var staleFinished=false;var staleResult:Bool?
        session.findText="serein-absent-find-token"
        session.find {staleResult=$0;staleFinished=true}
        session.findText="Workspaces"
        let latest=await search("Workspaces")
        for _ in 0..<40 where !staleFinished {try? await Task.sleep(for:.milliseconds(25))}
        check("find-old-query-cannot-overwrite-result",staleFinished && staleResult==nil && latest==true && session.findResult.isEmpty)
        check("find-empty-clears-result",await search("")==nil && session.findResult.isEmpty)
        let original=session.state.selectedTabID
        staleFinished=false;staleResult=nil
        session.findText="serein-absent-find-token"
        session.find {staleResult=$0;staleFinished=true}
        let other=session.newTab()
        for _ in 0..<40 where !staleFinished {try? await Task.sleep(for:.milliseconds(25))}
        check("find-old-tab-result-discarded",staleFinished && staleResult==nil)
        session.close(other,ask:false)
        if let original {session.select(original)}
        session.closeFind()
        try? await Task.sleep(for:.milliseconds(200))
        let view=session.current?.loadedWebView
        let responder=session.window?.firstResponder as? NSView
        check("find-close-restores-page-focus",!session.findVisible && view != nil && responder.map{candidate in candidate===view || view.map{candidate.isDescendant(of:$0)}==true}==true)
        return results
    }
}
