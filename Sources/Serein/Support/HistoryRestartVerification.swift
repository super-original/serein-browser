import AppKit
import WebKit
import SereinCore

/// Exercise the actual opt-in persistence path in two independent app processes.
@MainActor enum HistoryRestartVerification {
    static func run(manager:BrowserManager,root:URL,prepare:Bool,fallback:Bool=false) async {
        var results:[RuntimeVerification.Result]=[]
        func check(_ name:String,_ passed:Bool,_ detail:String="") {results.append(.init(name:"history-restart-"+name,passed:passed,detail:detail))}
        func wait(_ condition:@MainActor ()->Bool) async->Bool {
            for _ in 0..<100 {if condition(){return true};try? await Task.sleep(for:.milliseconds(50))};return false
        }
        guard let session=manager.active,let runtime=session.current else{return}
        let view=runtime.webView
        let first="http://127.0.0.1:8765/index.html?history=first"
        let second="http://127.0.0.1:8765/index.html?history=second"
        let third="http://127.0.0.1:8765/index.html?history=third"
        func snapshot()->String {
            "url=\(view.url?.absoluteString ?? "nil") current=\(view.backForwardList.currentItem?.url.absoluteString ?? "nil") back=\(view.backForwardList.backList.map{$0.url.absoluteString}) forward=\(view.backForwardList.forwardList.map{$0.url.absoluteString}) loading=\(view.isLoading)"
        }
        if fallback {
            let ready=await wait{view.url?.absoluteString==second && !view.isLoading && view.backForwardList.currentItem?.url.absoluteString==second}
            check("fallback-current-url",ready,snapshot())
            check("fallback-no-stale-history",ready && view.backForwardList.backList.isEmpty && view.backForwardList.forwardList.isEmpty,snapshot())
        } else if prepare {
            var loaded=true
            var steps:[String]=[]
            for url in [first,second,third] {
                session.navigate(url)
                let ready=await wait{view.url?.absoluteString==url && !view.isLoading && view.backForwardList.currentItem?.url.absoluteString==url}
                loaded=loaded && ready;steps.append("ready=\(ready) \(snapshot())")
            }
            runtime.goBack()
            let middle=await wait{view.url?.absoluteString==second && !view.isLoading && view.backForwardList.currentItem?.url.absoluteString==second && view.backForwardList.backItem?.url.absoluteString==first && view.backForwardList.forwardItem?.url.absoluteString==third}
            check("prepare-three-entry-history",loaded && middle,steps.joined(separator:"; ")+"; final="+snapshot())
            let saved=manager.saveNow()
            let disk=try? SavedSession.decode(Data(contentsOf:root.appendingPathComponent("session.json")))
            check("public-state-is-bounded-data",saved && disk?.navigationHistory?.count==1,"Production opt-in session contains one bounded history record")
        } else {
            do {
                let disk=try SavedSession.decode(Data(contentsOf:root.appendingPathComponent("session.json")))
                check("serialized-state-available",disk.navigationHistory?.count==1)
                // BrowserManager/TabRuntime already applied the saved record.
                let middle=await wait{view.url?.absoluteString==second && !view.isLoading && view.backForwardList.currentItem?.url.absoluteString==second && view.backForwardList.backItem?.url.absoluteString==first && view.backForwardList.forwardItem?.url.absoluteString==third}
                check("restored-current-and-both-directions",middle,snapshot())
                runtime.goBack()
                let back=await wait{view.url?.absoluteString==first && !view.isLoading}
                check("back-after-new-process",back,snapshot())
                runtime.goForward()
                let forward=await wait{view.url?.absoluteString==second && !view.isLoading}
                runtime.goForward()
                let end=await wait{view.url?.absoluteString==third && !view.isLoading}
                check("forward-after-new-process",forward && end,snapshot())
                let text=try? await view.evaluateJavaScript("document.title==='Field Notes' && document.body.innerText.includes('A little room to think.')")
                check("restored-document-executes",text as? Bool==true)
            } catch {check("read-state",false,error.localizedDescription)}
        }
        try? JSONEncoder().encode(results).write(to:root.appendingPathComponent(fallback ? "fallback-results.json" : prepare ? "prepare-results.json" : "resume-results.json"),options:.atomic)
    }
}
