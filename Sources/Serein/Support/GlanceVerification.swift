import AppKit
import WebKit

@MainActor enum GlanceVerification {
    static func run(manager:BrowserManager,root:URL) async -> [RuntimeVerification.Result] {
        var results:[RuntimeVerification.Result]=[]
        func check(_ name:String,_ passed:Bool,_ detail:String="") {results.append(.init(name:"glance-"+name,passed:passed,detail:detail))}
        func wait(_ condition:@MainActor ()->Bool) async {
            for _ in 0..<100 {if condition(){return};try? await Task.sleep(for:.milliseconds(50))}
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
        let parent=session.runtime(owner)
        session.navigate("http://127.0.0.1:8765/index.html?glance-owner",ask:false)
        await wait{parent.webView.url?.query=="glance-owner" && !parent.webView.isLoading}
        try? await Task.sleep(for:.milliseconds(200))
        let target=URL(string:"http://127.0.0.1:8765/second.html")!
        let point=try? await parent.webView.evaluateJavaScript("const a=document.querySelector('a');a.scrollIntoView({block:'center'});const r=a.getBoundingClientRect();({x:r.x+r.width/2,y:r.y+r.height/2})") as? [String:Double]
        if let point,let x=point["x"],let y=point["y"],let screen=NSScreen.screens.first {
            let view=parent.webView
            let local=NSPoint(x:x,y:view.isFlipped ? y : view.bounds.height-y)
            let location=window.convertPoint(toScreen:view.convert(local,to:nil))
            try? "\(Int(location.x.rounded())) \(Int((screen.frame.maxY-location.y).rounded()))\n".write(to:root.appendingPathComponent("glance-click-point"),atomically:true,encoding:.utf8)
            let sent=await keyboard("glance-option-click")
            await wait{session.state.activeGlance != nil}
            check("native-option-click-opens-preview",sent && session.state.activeGlance != nil)
        } else {check("native-option-click-opens-preview",false,"Could not locate the controlled link")}
        // Keep independent lifecycle checks useful if native input fails.
        if session.state.activeGlance==nil {session.openGlance(target,from:owner)}
        guard let preview=session.state.activeGlance else{window.close();return results}
        let runtime=session.runtime(preview.id),view=runtime.webView
        await wait{view.url==target && !view.isLoading}
        check("loads-with-parent-store",view.url==target && view.configuration.websiteDataStore === parent.webView.configuration.websiteDataStore)
        check("owner-preserved-and-preview-hidden",parent.webView.url?.query=="glance-owner" && session.state.visibleTabs.map(\.id)==[owner] && session.state.sidebarSelectedTabID==owner)
        check("visible-owner-cannot-unload",!session.canUnload(owner) && !session.canUnload(preview.id))
        try? "32-glance".write(to:root.appendingPathComponent("capture-request"),atomically:true,encoding:.utf8)
        await wait{FileManager.default.fileExists(atPath:root.appendingPathComponent("32-glance.capture-finished").path)}
        let rect=view.convert(view.bounds,to:nil)
        check("native-preview-geometry",abs(rect.width-604.8)<2 && abs(rect.height-661)<2,"\(rect)")
        let originalFrame=window.frame
        window.setFrame(NSRect(x:10,y:60,width:640,height:400),display:true)
        try? await Task.sleep(for:.milliseconds(200))
        let small=view.convert(view.bounds,to:nil)
        check("minimum-window-controls-fit",small.width>0 && small.maxX+56 <= (window.contentView?.bounds.width ?? 0)-7,"\(small)")
        try? "33-glance-minimum".write(to:root.appendingPathComponent("capture-request"),atomically:true,encoding:.utf8)
        await wait{FileManager.default.fileExists(atPath:root.appendingPathComponent("33-glance-minimum.capture-finished").path)}
        window.setFrame(originalFrame,display:true)
        let neighbor=session.newTab(select:false)
        let advanced=await keyboard("glance-next-tab")
        check("native-cycle-leaves-preview",advanced && session.state.selectedTabID==neighbor)
        let returned=await keyboard("glance-previous-tab")
        check("native-cycle-returns-preview",returned && session.state.activeGlance?.id==preview.id && runtime.loadedWebView === view)
        session.close(neighbor,ask:false)
        runtime.hasUserEdits=true
        session.close(owner)
        check("owner-close-prompts-for-preview-edits",window.attachedSheet != nil,"Native sheet; edit flag injected for consent testing")
        let changedTarget=URL(string:target.absoluteString+"?changed-consent")!
        runtime.load(changedTarget)
        if let sheet=window.attachedSheet {window.endSheet(sheet,returnCode:.alertFirstButtonReturn)}
        try? await Task.sleep(for:.milliseconds(200))
        check("changed-preview-invalidates-owner-consent",session.state.tabs.contains{$0.id==preview.id} && session.state.tabs.contains{$0.id==owner})
        await wait{view.url==changedTarget && !view.isLoading}
        check("changed-preview-loads",view.url==changedTarget && !view.isLoading)
        runtime.hasUserEdits=false
        _=try? await view.evaluateJavaScript("window.sereinGlanceSentinel='retained'")
        session.expandGlance()
        try? await Task.sleep(for:.milliseconds(150))
        let retained=try? await view.evaluateJavaScript("window.sereinGlanceSentinel") as? String
        check("expand-preserves-live-view",session.state.activeGlance==nil && session.state.visibleTabs.count==2 && session.current?.loadedWebView === view && retained=="retained")
        session.close(preview.id,ask:false);session.select(owner);session.openGlance(target,from:owner)
        if let next=session.state.activeGlance {
            let nextRuntime=session.runtime(next.id),nextView=nextRuntime.webView
            await wait{nextView.url==target && !nextView.isLoading}
            let destination=manager.newWindow()
            manager.moveTab(owner,from:session,to:destination)
            check("move-owner-carries-live-preview",destination.state.activeGlance?.id==next.id && destination.runtimes[next.id] === nextRuntime && nextRuntime.loadedWebView === nextView && session.runtimes[next.id]==nil && nextRuntime.session === destination)
            manager.moveTab(owner,from:destination,to:session)
            destination.window?.close()
            session.window?.makeKeyAndOrderFront(nil)
            session.splitGlance()
            check("split-retains-live-preview",session.state.splitTabIDs==[owner,next.id] && session.state.activeGlance==nil && session.runtime(next.id).loadedWebView === nextView)
            session.close(next.id,ask:false)
        }
        session.select(owner);session.openGlance(target,from:owner)
        if let last=session.state.activeGlance {
            try? await Task.sleep(for:.milliseconds(200))
            _=try? await parent.webView.evaluateJavaScript("window.sereinGlanceKey=event=>{if(event.key==='k'){document.documentElement.dataset.glanceKey='received';event.preventDefault();}};document.addEventListener('keydown',window.sereinGlanceKey,true)")
            let escaped=await keyboard("glance-escape")
            await wait{session.state.activeGlance==nil}
            check("native-escape-closes-preview",escaped && session.state.selectedTabID==owner && !session.state.tabs.contains{$0.id==last.id})
            let typed=await keyboard("find-page-key")
            let delivered=try? await parent.webView.evaluateJavaScript("document.documentElement.dataset.glanceKey || ''") as? String
            check("close-returns-parent-keyboard",typed && delivered=="received",String(describing:delivered))
        }
        let privateSession=manager.newWindow(isPrivate:true)
        if let privateOwner=privateSession.state.selectedTabID {
            privateSession.openGlance(target,from:privateOwner)
            if let privatePreview=privateSession.state.activeGlance {
                let privateView=privateSession.runtime(privatePreview.id).webView
                check("private-preview-isolated",!privateView.configuration.websiteDataStore.isPersistent && privateView.configuration.websiteDataStore === privateSession.dataStore && privateView.configuration.websiteDataStore !== session.dataStore && privateView.configuration.webExtensionController==nil)
                privateSession.close(privateOwner,ask:false)
                check("owner-close-disposes-preview",privateSession.runtimes[privatePreview.id]==nil && !privateSession.state.tabs.contains{$0.id==privatePreview.id})
            }
        }
        privateSession.window?.close();window.close()
        return results
    }
}
