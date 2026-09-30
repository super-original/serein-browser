import AppKit

@MainActor enum FindVerification {
    static func run(session:BrowserSession,root:URL) async -> [RuntimeVerification.Result] {
        var results:[RuntimeVerification.Result]=[]
        func check(_ name:String,_ passed:Bool,_ detail:String=""){results.append(.init(name:name,passed:passed,detail:"Public WKWebView.find against the deterministic fixture. "+detail))}
        func search(_ query:String,backwards:Bool=false) async -> Bool? {
            session.findText=query
            return await withCheckedContinuation {continuation in
                session.find(backwards:backwards){continuation.resume(returning:$0)}
            }
        }
        session.findVisible=true
        try? await Task.sleep(for:.milliseconds(250))
        let missing=await search("serein-absent-find-token")
        check("find-missing-query",missing==false && session.findResult=="No matches","result=\(String(describing:missing)) label=\(session.findResult)")
        let found=await search("Workspaces")
        check("find-existing-query",found==true && session.findResult.isEmpty,"result=\(String(describing:found)) label=\(session.findResult)")
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
        check("find-close-restores-page-focus",!session.findVisible && view != nil && responder.map{candidate in candidate===view || view.map{candidate.isDescendant(of:$0)}==true}==true,"responder=\(String(describing:responder)) attached=\(view?.window === session.window) addressFocused=\(session.addressFocused)")
        func keyboard(_ name:String) async -> Bool {
            let finished=root.appendingPathComponent(name+".keyboard-finished")
            try? FileManager.default.removeItem(at:finished)
            try? name.write(to:root.appendingPathComponent("keyboard-request"),atomically:true,encoding:.utf8)
            for _ in 0..<80 {
                if FileManager.default.fileExists(atPath:finished.path){return true}
                try? await Task.sleep(for:.milliseconds(50))
            }
            return false
        }
        session.window?.makeKeyAndOrderFront(nil)
        let entered=await keyboard("find-query")
        for _ in 0..<30 where session.findText != "Workspaces" {try? await Task.sleep(for:.milliseconds(50))}
        check("find-native-command-f-and-entry",entered && session.findVisible && session.findText=="Workspaces",session.findText)
        _=try? await session.current?.webView.evaluateJavaScript("window.sereinFindKey = event => { if(event.key==='k'){document.documentElement.dataset.findKey='received';event.preventDefault();} }; document.addEventListener('keydown',window.sereinFindKey,true)")
        let escaped=await keyboard("find-escape")
        try? await Task.sleep(for:.milliseconds(200))
        let typed=await keyboard("find-page-key")
        let delivered=try? await session.current?.webView.evaluateJavaScript("document.documentElement.dataset.findKey || ''") as? String
        check("find-native-escape-returns-web-keyboard",escaped && typed && !session.findVisible && delivered=="received",String(describing:delivered))
        _=try? await session.current?.webView.evaluateJavaScript("document.removeEventListener('keydown',window.sereinFindKey,true);delete window.sereinFindKey;delete document.documentElement.dataset.findKey")
        return results
    }
}
