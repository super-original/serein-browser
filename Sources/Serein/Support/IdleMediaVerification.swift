import AppKit
import WebKit

/// Native pointer input and real decoded audio complement controlled policy replies.
@MainActor enum IdleMediaVerification {
    static func run(session:BrowserSession,root:URL) async->[RuntimeVerification.Result] {
        var results:[RuntimeVerification.Result]=[]
        func check(_ name:String,_ pass:Bool,_ detail:String=""){results.append(.init(name:"idle-media-"+name,passed:pass,detail:detail))}
        func wait(_ condition:@MainActor ()->Bool) async {for _ in 0..<100{if condition(){return};try? await Task.sleep(for:.milliseconds(50))}}
        guard let manager=session.manager,let window=session.window else{return results}
        let owner=session.state.selectedTabID,id=session.newTab(url:"http://127.0.0.1:8765/idle-media.html")
        let runtime=session.runtime(id),view=runtime.webView
        defer{session.close(id,ask:false);if let owner{session.select(owner)}}
        window.makeKeyAndOrderFront(nil)
        await wait{view.title=="Serein idle media fixture" && !view.isLoading && view.window===window}
        let point=try? await view.evaluateJavaScript("(()=>{const r=document.querySelector('#play').getBoundingClientRect();return {x:r.x+r.width/2,y:r.y+r.height/2}})()") as? [String:Double]
        guard let point,let x=point["x"],let y=point["y"],let screen=NSScreen.screens.first else{check("setup",false,"Missing media control");return results}
        let location=window.convertPoint(toScreen:view.convert(NSPoint(x:x,y:view.isFlipped ? y : view.bounds.height-y),to:nil))
        try? "\(Int(location.x.rounded())) \(Int((screen.frame.maxY-location.y).rounded()))\n".write(to:root.appendingPathComponent("idle-media-click-point"),atomically:true,encoding:.utf8)
        let done=root.appendingPathComponent("idle-media-play.keyboard-finished")
        try? "idle-media-play".write(to:root.appendingPathComponent("keyboard-request"),atomically:true,encoding:.utf8)
        await wait{FileManager.default.fileExists(atPath:done.path)}
        var media:[String:Any]?
        for _ in 0..<40 {
            media=try? await view.evaluateJavaScript("({...window.mediaAttempt,paused:track.paused,time:track.currentTime,error:track.error?.message || window.mediaAttempt?.error || null})") as? [String:Any]
            if (media?["time"] as? Double ?? 0)>0.05 {break}
            try? await Task.sleep(for:.milliseconds(50))
        }
        let started=FileManager.default.fileExists(atPath:done.path) && !FileManager.default.fileExists(atPath:root.appendingPathComponent("idle-media-play.keyboard-failed").path) && media?["trusted"] as? Bool==true && media?["started"] as? Bool==true && media?["paused"] as? Bool==false && (media?["time"] as? Double ?? 0)>0.05
        check("native-gesture-starts-decoded-audio",started,String(describing:media))
        guard started else{return results}
        let foreground=await TabSuspensionController.playbackState(view)
        check("public-playing-state",foreground==WKMediaPlaybackState.playing,String(describing:foreground))
        if let owner{session.select(owner)}else{session.newTab()}
        await wait{view.window==nil}
        runtime.noteActivity(at:ContinuousClock().now.advanced(by:.seconds(-16*60)))
        let playingCount=await manager.tabSuspension.sweep(idleMinutes:15)
        check("inactive-playing-page-retained",playingCount==0 && runtime.loadedWebView === view)
        _=try? await view.evaluateJavaScript("track.pause()")
        let paused=await TabSuspensionController.playbackState(view)
        check("public-paused-state",paused==WKMediaPlaybackState.paused,String(describing:paused))
        runtime.noteActivity(at:ContinuousClock().now.advanced(by:.seconds(-16*60)))
        let pausedCount=await manager.tabSuspension.sweep(idleMinutes:15)
        check("inactive-paused-page-retained",pausedCount==0 && runtime.loadedWebView === view)
        return results
    }
}
