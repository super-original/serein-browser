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
        let first="http://127.0.0.1:8765/index.html?history=first"
        let second="http://127.0.0.1:8765/index.html?history=second"
        let third="http://127.0.0.1:8765/index.html?history=third"
        guard let session=manager.active else{return}
        if !prepare,let restored=session.state.tabs.first(where:{$0.url==second}) {session.select(restored.id)}
        guard let runtime=session.current else{return}
        let view=runtime.webView
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
            let privateSession=manager.newWindow(isPrivate:true)
            let privateURL=first+"&private-history=1"
            privateSession.navigate(privateURL,ask:false)
            let privateView=privateSession.current!.webView
            let privateReady=await wait{privateView.url?.absoluteString==privateURL && !privateView.isLoading && privateView.interactionState is Data}
            let privateSaved=manager.saveNow()
            let privateDisk=try? SavedSession.decode(Data(contentsOf:root.appendingPathComponent("session.json")))
            check("live-private-history-excluded",privateReady && privateSaved && privateDisk?.windows.count==1 && privateDisk?.navigationHistory?.count==1 && privateDisk?.navigationHistory?.first?.windowID==session.state.id)
            privateSession.window?.close()
            session.window?.makeKeyAndOrderFront(nil)
            _=try? await view.evaluateJavaScript("const input=document.querySelector('input');input.value='owned history fixture edit';input.dispatchEvent(new Event('input',{bubbles:true}));")
            let edited=await wait{runtime.hasUserEdits}
            let editedSaved=manager.saveNow()
            let editedDisk=try? SavedSession.decode(Data(contentsOf:root.appendingPathComponent("session.json")))
            check("detected-page-edits-exclude-opaque-state",edited && editedSaved && editedDisk != nil && editedDisk?.navigationHistory==nil)
            runtime.reload()
            let reloaded=await wait{!runtime.hasUserEdits && !view.isLoading && view.url?.absoluteString==second && view.backForwardList.backItem?.url.absoluteString==first && view.backForwardList.forwardItem?.url.absoluteString==third}
            check("reload-after-edit-retains-navigation",reloaded,snapshot())
            _=session.newTab()
            runtime.suspend()
            let savedUnloaded=manager.saveNow()
            let unloadedDisk=try? SavedSession.decode(Data(contentsOf:root.appendingPathComponent("session.json")))
            check("unloaded-background-history-persisted",savedUnloaded && runtime.loadedWebView==nil && unloadedDisk?.navigationHistory?.first?.tabID==runtime.id)
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
