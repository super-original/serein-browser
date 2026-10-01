import AppKit
import WebKit
import SereinCore

/// A fixture-only experiment with the public opaque interaction-state value.
/// Production session persistence is unchanged until separate-process semantics
/// and an explicit storage/version/privacy policy are established.
@MainActor enum HistoryRestartVerification {
    static func run(manager:BrowserManager,root:URL,prepare:Bool) async {
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
        let file=root.appendingPathComponent("fixture-interaction-state.bin")
        func snapshot()->String {
            "url=\(view.url?.absoluteString ?? "nil") current=\(view.backForwardList.currentItem?.url.absoluteString ?? "nil") back=\(view.backForwardList.backList.map{$0.url.absoluteString}) forward=\(view.backForwardList.forwardList.map{$0.url.absoluteString}) loading=\(view.isLoading)"
        }
        if prepare {
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
            if let data=view.interactionState as? Data,!data.isEmpty,data.count<=2*1024*1024 {
                do {try PrivateFileStore.write(data,to:file);check("public-state-is-bounded-data",true,"\(data.count) bytes; opaque fixture state only")}
                catch {check("public-state-is-bounded-data",false,error.localizedDescription)}
            } else {check("public-state-is-bounded-data",false,"Public state was not a nonempty Data value within the fixture bound")}
        } else {
            do {
                let data=try Data(contentsOf:file)
                check("serialized-state-available",!data.isEmpty && data.count<=2*1024*1024)
                // Finish the ordinary URL-only startup before replacing its state.
                _=await wait{view.backForwardList.currentItem?.url.absoluteString==second && !view.isLoading}
                view.interactionState=data
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
        try? JSONEncoder().encode(results).write(to:root.appendingPathComponent(prepare ? "prepare-results.json" : "resume-results.json"),options:.atomic)
    }
}
