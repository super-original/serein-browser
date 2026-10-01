import AppKit
import SereinCore

@MainActor enum CrashRecoveryVerification {
    static func run(manager:BrowserManager,root:URL) async {
        var results:[RuntimeVerification.Result]=[]
        func check(_ name:String,_ passed:Bool,_ detail:String="") {results.append(.init(name:name,passed:passed,detail:detail))}
        func wait(_ condition:()->Bool) async -> Bool {
            for _ in 0..<160 {if condition(){return true};try? await Task.sleep(for:.milliseconds(50))}
            return false
        }
        func capture(_ name:String) async {
            try? name.write(to:root.appendingPathComponent("capture-request"),atomically:true,encoding:.utf8)
            let completed=await wait{FileManager.default.fileExists(atPath:root.appendingPathComponent(name+".capture-finished").path)}
            check("capture-"+name,completed && FileManager.default.fileExists(atPath:root.appendingPathComponent(name+".png").path))
        }
        if let session=manager.active {
            let url=URL(string:"http://127.0.0.1:8765/index.html?crash-recovery=1")!
            session.navigate(url.absoluteString,ask:false)
            if let runtime=session.current {
                let view=runtime.webView
                let loaded=await wait{view.url==url && view.title=="Field Notes" && !runtime.isLoading}
                check("initial-fixture-loaded",loaded)
                let originalDocument=runtime.documentID
                if loaded {
                    let ready=["pid":ProcessInfo.processInfo.processIdentifier]
                    try? JSONEncoder().encode(ready).write(to:root.appendingPathComponent("ready.json"),options:.atomic)
                    let signalled=await wait{FileManager.default.fileExists(atPath:root.appendingPathComponent("process-terminated").path)}
                    let stopped=await wait{runtime.crashed && runtime.failure != nil && !runtime.isLoading}
                    check("real-web-process-termination-reaches-delegate",signalled && stopped)
                    check("crash-invalidates-document-identity",stopped && runtime.documentID != originalDocument)
                    if stopped {
                        await capture("01-crashed-page")
                        try? Data().write(to:root.appendingPathComponent("reload-request"))
                        let input=await wait{FileManager.default.fileExists(atPath:root.appendingPathComponent("reload-input-finished").path)}
                        let inputSucceeded=(try? String(contentsOf:root.appendingPathComponent("reload-input-finished"),encoding:.utf8))=="true"
                        let recovered=await wait{!runtime.crashed && runtime.failure==nil && !runtime.isLoading && view.url==url && view.title=="Field Notes"}
                        let body=try? await view.evaluateJavaScript("document.body.innerText") as? String
                        check("native-error-reload-recovers-document",input && inputSucceeded && recovered && body?.contains("A little room to think.")==true)
                        check("recovery-retains-tab-and-view-identity",session.current===runtime && runtime.loadedWebView===view)
                        await capture("02-recovered-page")
                    }
                }
            } else {check("runtime-setup",false)}
        } else {check("window-setup",false)}
        try? JSONEncoder().encode(results).write(to:root.appendingPathComponent("results.json"),options:.atomic)
        NSApp.terminate(nil)
    }
}
