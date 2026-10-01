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
        if prepare {
            var loaded=true
            for url in [first,second,third] {
                session.navigate(url)
                let ready=await wait{view.url?.absoluteString==url && !runtime.isLoading && view.backForwardList.currentItem?.url.absoluteString==url}
                loaded=loaded && ready
            }
            runtime.goBack()
            let middle=await wait{view.url?.absoluteString==second && !runtime.isLoading}
            check("prepare-three-entry-history",loaded && middle && view.backForwardList.backItem?.url.absoluteString==first && view.backForwardList.forwardItem?.url.absoluteString==third)
            if let data=view.interactionState as? Data,!data.isEmpty,data.count<=2*1024*1024 {
                do {try PrivateFileStore.write(data,to:file);check("public-state-is-bounded-data",true,"\(data.count) bytes; opaque fixture state only")}
                catch {check("public-state-is-bounded-data",false,error.localizedDescription)}
            } else {check("public-state-is-bounded-data",false,"Public state was not a nonempty Data value within the fixture bound")}
        } else {
            do {
                let data=try Data(contentsOf:file)
                check("serialized-state-available",!data.isEmpty && data.count<=2*1024*1024)
                // Finish the ordinary URL-only startup before replacing its state.
                _=await wait{view.backForwardList.currentItem?.url.absoluteString==second && !runtime.isLoading}
                view.interactionState=data
                let middle=await wait{view.url?.absoluteString==second && !runtime.isLoading}
                check("restored-current-and-both-directions",middle && view.backForwardList.backItem?.url.absoluteString==first && view.backForwardList.forwardItem?.url.absoluteString==third)
                runtime.goBack()
                let back=await wait{view.url?.absoluteString==first && !runtime.isLoading}
                check("back-after-new-process",back)
                runtime.goForward()
                let forward=await wait{view.url?.absoluteString==second && !runtime.isLoading}
                runtime.goForward()
                let end=await wait{view.url?.absoluteString==third && !runtime.isLoading}
                check("forward-after-new-process",forward && end)
                let text=try? await view.evaluateJavaScript("document.body.innerText.includes('Field Notes')")
                check("restored-document-executes",text as? Bool==true)
            } catch {check("read-state",false,error.localizedDescription)}
        }
        try? JSONEncoder().encode(results).write(to:root.appendingPathComponent(prepare ? "prepare-results.json" : "resume-results.json"),options:.atomic)
    }
}
