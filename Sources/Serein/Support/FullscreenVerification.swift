import AppKit
import WebKit

@MainActor enum FullscreenVerification {
    static func run(manager:BrowserManager,root:URL) async -> [RuntimeVerification.Result] {
        let ordinary=await scenario(manager:manager,root:root,preview:false)
        let glance=await scenario(manager:manager,root:root,preview:true)
        return ordinary+glance
    }
    private static func scenario(manager:BrowserManager,root:URL,preview:Bool) async -> [RuntimeVerification.Result] {
        var results:[RuntimeVerification.Result]=[]
        func check(_ name:String,_ passed:Bool,_ detail:String="") {results.append(.init(name:(preview ? "fullscreen-glance-" : "fullscreen-page-")+name,passed:passed,detail:detail))}
        func wait(_ condition:@MainActor ()->Bool) async {
            for _ in 0..<150 {if condition(){return};try? await Task.sleep(for:.milliseconds(50))}
        }
        func keyboard(_ name:String) async -> Bool {
            let finished=root.appendingPathComponent(name+".keyboard-finished")
            try? FileManager.default.removeItem(at:finished)
            try? name.write(to:root.appendingPathComponent("keyboard-request"),atomically:true,encoding:.utf8)
            await wait{FileManager.default.fileExists(atPath:finished.path)}
            return FileManager.default.fileExists(atPath:finished.path)
        }
        let session=manager.newWindow()
        guard let owner=session.state.selectedTabID,let window=session.window else{return []}
        defer {window.close()}
        if preview {session.openGlance(URL(string:"http://127.0.0.1:8765/fullscreen.html")!,from:owner)}
        else {session.navigate("http://127.0.0.1:8765/fullscreen.html",ask:false)}
        guard let id=session.state.selectedTabID else{return []}
        let view=session.runtime(id).webView
        window.makeKeyAndOrderFront(nil)
        await wait{view.window === window && view.bounds.width>200 && view.url?.path=="/fullscreen.html" && !view.isLoading}
        let point=try? await view.evaluateJavaScript("(()=>{const r=document.querySelector('#enter').getBoundingClientRect();return {x:r.x+r.width/2,y:r.y+r.height/2}})()") as? [String:Double]
        guard let point,let x=point["x"],let y=point["y"],let screen=NSScreen.screens.first else {
            check("native-click",false,"Could not locate fixture control");return results
        }
        let local=NSPoint(x:x,y:view.isFlipped ? y : view.bounds.height-y)
        let location=window.convertPoint(toScreen:view.convert(local,to:nil))
        try? "\(Int(location.x.rounded())) \(Int((screen.frame.maxY-location.y).rounded()))\n".write(to:root.appendingPathComponent("fullscreen-click-point"),atomically:true,encoding:.utf8)
        let clicked=await keyboard("fullscreen-enter")
        await wait{view.fullscreenState == .inFullscreen}
        let dom=try? await view.evaluateJavaScript("document.fullscreenElement?.id || document.documentElement.dataset.fullscreenError || 'none'") as? String
        let diagnostic=try? await view.evaluateJavaScript("JSON.stringify(window.fullscreenAttempt || {})") as? String
        let entered=clicked && view.fullscreenState == .inFullscreen && dom=="stage"
        check("native-entry",clicked && view.fullscreenState == .inFullscreen,"state=\(view.fullscreenState.rawValue) DOM=\(String(describing:dom)) preference=\(view.configuration.preferences.isElementFullscreenEnabled) key=\(window.isKeyWindow) details=\(String(describing:diagnostic))")
        check("dom-entry",dom=="stage")
        let capture=preview ? "36-glance-fullscreen" : "35-element-fullscreen"
        try? capture.write(to:root.appendingPathComponent("capture-request"),atomically:true,encoding:.utf8)
        await wait{FileManager.default.fileExists(atPath:root.appendingPathComponent(capture+".capture-finished").path)}
        let escaped=await keyboard("fullscreen-exit")
        await wait{view.fullscreenState == .notInFullscreen && view.window === window}
        let exited=try? await view.evaluateJavaScript("document.fullscreenElement===null") as? Bool
        check("native-escape-restores-window",entered && escaped && view.fullscreenState == .notInFullscreen && view.window === window && session.current?.loadedWebView === view)
        check("dom-exit",entered && exited==true)
        if preview {check("escape-preserves-preview",entered && session.state.activeGlance?.id==id && session.state.activeGlance?.glanceParentID==owner)}
        // Retain failed Escape assertions, then clean up this fixture's mode so
        // unrelated browser/extension scenarios can continue independently.
        if view.fullscreenState != .notInFullscreen {
            _=try? await view.evaluateJavaScript("document.exitFullscreen()")
            await wait{view.fullscreenState == .notInFullscreen}
        }
        return results
    }
}
