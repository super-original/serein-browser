import AppKit
import WebKit
import SereinCore

@MainActor enum IdleSuspensionVerification {
    static func run(root:URL) async->[RuntimeVerification.Result] {
        var results:[RuntimeVerification.Result]=[]
        func check(_ name:String,_ pass:Bool,_ detail:String=""){results.append(.init(name:"idle-suspension-"+name,passed:pass,detail:detail))}
        func wait(_ condition:@MainActor ()->Bool) async {for _ in 0..<100{if condition(){return};try? await Task.sleep(for:.milliseconds(50))}}
        let manager=BrowserManager(root:root.appendingPathComponent("idle-suspension")),session=manager.newWindow()
        defer{for window in manager.windows {window.window?.close()}}
        let id=session.state.selectedTabID!,runtime=session.runtime(id)
        for path in ["index.html?idle=first","second.html?idle=second"] {
            let url=URL(string:"http://127.0.0.1:8765/"+path)!
            runtime.load(url);await wait{runtime.loadedWebView?.url==url && runtime.loadedWebView?.isLoading==false}
        }
        _=runtime.setZoom(1.3)
        let expected=runtime.loadedWebView?.url,history=runtime.loadedWebView?.backForwardList.backList.map(\.url)
        let active=session.newTab(),controller=manager.tabSuspension
        let now=Date(),old=now.addingTimeInterval(-16*60)
        await wait{runtime.loadedWebView?.window==nil}
        func age(){runtime.noteActivity(at:old)}
        func kept(_ name:String,_ policy:TabSuspensionController?=nil,minutes:Int=15) async {
            let count=await (policy ?? controller).sweep(now:now,idleMinutes:minutes)
            check(name,count==0 && runtime.loadedWebView != nil)
        }
        age();await kept("off-keeps-page",minutes:0)
        age();await kept("invalid-setting-keeps-page",minutes:-1)
        runtime.noteActivity(at:now);await kept("recent-page-kept")
        session.select(id);age();await kept("selected-page-kept")
        session.select(active);await wait{runtime.loadedWebView?.window==nil}
        runtime.hasUserEdits=true;age();await kept("edited-page-kept");runtime.hasUserEdits=false
        session.setKind(id,.pinned);age();await kept("pinned-page-kept");session.setKind(id,.regular)
        session.openGlance(URL(string:"http://127.0.0.1:8765/index.html?idle=preview")!,from:id)
        let preview=session.state.glance(for:id)?.id
        session.select(active);age();await kept("preview-owner-kept")
        if let preview {session.close(preview,ask:false)}
        session.select(active);await wait{runtime.loadedWebView?.window==nil}
        let download=DownloadItem(record:.init(name:"Idle policy fixture",phase:.downloading),store:manager.downloads)
        manager.downloads.items.append(download);age();await kept("active-download-state-keeps-page")
        manager.downloads.items.removeAll{$0.id==download.id}
        // Controlled responses exercise failure/race policy separately from the
        // actual public no-media query used for the unload/restore below.
        age();await kept("unknown-media-kept",TabSuspensionController(manager:manager,mediaState:{_ in nil}))
        age();await kept("playing-media-kept",TabSuspensionController(manager:manager,mediaState:{_ in .playing}))
        age();await kept("paused-media-kept",TabSuspensionController(manager:manager,mediaState:{_ in .paused}))
        age();await kept("activation-during-query-kept",TabSuspensionController(manager:manager,mediaState:{_ in session.select(id);return WKMediaPlaybackState.none}))
        session.select(active);await wait{runtime.loadedWebView?.window==nil}
        age();await kept("activity-during-query-kept",TabSuspensionController(manager:manager,mediaState:{_ in runtime.noteActivity();return WKMediaPlaybackState.none}))
        age();await kept("navigation-during-query-kept",TabSuspensionController(manager:manager,mediaState:{_ in runtime.load(URL(string:"http://127.0.0.1:8765/second.html?idle=replaced")!);return WKMediaPlaybackState.none}))
        await wait{runtime.loadedWebView?.url?.query=="idle=replaced" && runtime.loadedWebView?.isLoading==false}
        runtime.goBack();await wait{runtime.loadedWebView?.url==expected && runtime.loadedWebView?.isLoading==false}
        let savedForward=runtime.loadedWebView?.backForwardList.forwardList.map(\.url)
        let privateSession=manager.newWindow(isPrivate:true)
        let privateTab=privateSession.state.selectedTabID!,privateRuntime=privateSession.current!
        privateRuntime.load(URL(string:"http://127.0.0.1:8765/index.html?idle=private")!)
        await wait{privateRuntime.loadedWebView?.url?.query=="idle=private" && privateRuntime.loadedWebView?.isLoading==false}
        privateSession.newTab();privateRuntime.noteActivity(at:old)
        runtime.noteActivity(at:now)
        let privateCount=await controller.sweep(now:now,idleMinutes:15)
        check("private-inactive-page-kept",privateCount==0 && privateSession.runtimes[privateTab]?.loadedWebView != nil)
        age()
        weak var previous=runtime.loadedWebView
        let count=await controller.sweep(now:now,idleMinutes:15)
        check("public-media-check-unloads-idle-page",count==1 && runtime.loadedWebView==nil && abs(runtime.zoomFactor-1.3)<0.001)
        await wait{previous==nil}
        check("old-view-released",previous==nil)
        session.select(id)
        await wait{runtime.loadedWebView?.url==expected && runtime.loadedWebView?.isLoading==false}
        check("restores-history-position-and-zoom",runtime.loadedWebView?.url==expected && runtime.loadedWebView?.backForwardList.backList.map(\.url)==history && runtime.loadedWebView?.backForwardList.forwardList.map(\.url)==savedForward && abs(runtime.zoomFactor-1.3)<0.001)
        session.window?.makeKeyAndOrderFront(nil);session.libraryPanel = .settings
        await wait{session.window?.attachedSheet != nil}
        try? "57-idle-tab-settings".write(to:root.appendingPathComponent("capture-request"),atomically:true,encoding:.utf8)
        await wait{FileManager.default.fileExists(atPath:root.appendingPathComponent("57-idle-tab-settings.capture-finished").path)}
        check("settings-capture",FileManager.default.fileExists(atPath:root.appendingPathComponent("57-idle-tab-settings.png").path))
        session.libraryPanel=nil
        await wait{session.window?.attachedSheet==nil}
        return results
    }
}
