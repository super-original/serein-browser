import AppKit
import WebKit
import SereinCore

@MainActor enum SidebarDropVerification {
    static func run(manager:BrowserManager,root:URL) async->[RuntimeVerification.Result] {
        var results:[RuntimeVerification.Result]=[]
        func check(_ name:String,_ passed:Bool,_ detail:String=""){results.append(.init(name:"sidebar-drop-"+name,passed:passed,detail:detail))}
        func wait(_ condition:@MainActor ()->Bool) async {for _ in 0..<160 {if condition(){return};try? await Task.sleep(for:.milliseconds(50))}}
        let source=manager.newWindow(),destination=manager.newWindow()
        defer{source.window?.close();destination.window?.close()}
        guard let moving=source.state.selectedTabID,let before=destination.state.selectedTabID else{return results}
        let runtime=source.runtime(moving),view=runtime.webView
        for path in ["index.html?drag-first","second.html?drag-live"] {
            let url=URL(string:"http://127.0.0.1:8765/"+path)!
            runtime.load(url);await wait{view.url==url && !view.isLoading}
        }
        _=runtime.setZoom(1.4)
        _=try? await view.evaluateJavaScript("window.sereinDragSentinel='live';document.dispatchEvent(new Event('input',{bubbles:true}))")
        await wait{runtime.hasUserEdits}
        let history=view.backForwardList.backList.map(\.url),payload=source.sidebarDrag(moving,kind:.tab)
        check("live-setup",runtime.hasUserEdits && !history.isEmpty && view.url?.query=="drag-live")
        source.window?.setFrame(NSRect(x:380,y:70,width:640,height:600),display:true)
        destination.window?.setFrame(NSRect(x:10,y:70,width:640,height:600),display:true)
        destination.window?.makeKeyAndOrderFront(nil)
        try? await Task.sleep(for:.milliseconds(250))
        let name="sidebar-cross-window-drag",done=root.appendingPathComponent(name+".keyboard-finished"),failed=root.appendingPathComponent(name+".keyboard-failed")
        try? FileManager.default.removeItem(at:done);try? FileManager.default.removeItem(at:failed)
        try? "tab-\(moving)\ntab-\(before)\n".write(to:root.appendingPathComponent("sidebar-drag-identifiers"),atomically:true,encoding:.utf8)
        try? name.write(to:root.appendingPathComponent("keyboard-request"),atomically:true,encoding:.utf8)
        await wait{FileManager.default.fileExists(atPath:done.path)}
        await wait{destination.state.tabs.contains{$0.id==moving}}
        check("actual-cross-window-drag",FileManager.default.fileExists(atPath:done.path) && !FileManager.default.fileExists(atPath:failed.path) && destination.state.tabs.contains{$0.id==moving})
        // A failed native gesture remains failed; keep the model-boundary checks independent.
        if !destination.state.tabs.contains(where:{$0.id==moving}) {
            check("controlled-drop-after-input-failure",destination.acceptSidebarDrop([payload],at:.beforeTab(before)))
        }
        await wait{view.window === destination.window && view.bounds.width>0}
        check("same-live-view-and-store",destination.runtimes[moving] === runtime && source.runtimes[moving]==nil && runtime.loadedWebView === view && view.configuration.websiteDataStore === destination.dataStore && view.window === destination.window)
        let sentinel=try? await view.evaluateJavaScript("window.sereinDragSentinel") as? String
        check("preserves-edits-history-and-zoom",runtime.hasUserEdits && sentinel=="live" && view.backForwardList.backList.map(\.url)==history && abs(view.pageZoom-1.4)<0.001)
        check("inserts-before-target",destination.state.visibleTabs.map(\.id)==[moving,before] && source.state.visibleTabs.count==1)
        check("stale-source-rejected",!destination.acceptSidebarDrop([payload],at:.beforeTab(before)))
        let current=destination.sidebarDrag(moving,kind:.tab)
        let forged=SidebarDragItem(token:UUID(),window:current.window,item:current.item,kind:.tab)
        check("foreign-token-rejected",!source.acceptSidebarDrop([forged],at:.beforeTab(source.state.selectedTabID!)))
        check("batch-rejected",!source.acceptSidebarDrop([current,current],at:.beforeTab(source.state.selectedTabID!)))
        let privateWindow=manager.newWindow(isPrivate:true)
        defer{privateWindow.window?.close()}
        let privateFirst=privateWindow.state.selectedTabID!,privateSecond=privateWindow.newTab()
        let privatePayload=privateWindow.sidebarDrag(privateFirst,kind:.tab)
        check("normal-to-private-rejected",!privateWindow.acceptSidebarDrop([current],at:.beforeTab(privateFirst)) && destination.runtimes[moving] === runtime)
        check("private-to-normal-rejected",!destination.acceptSidebarDrop([privatePayload],at:.beforeTab(before)))
        check("private-local-reorder",privateWindow.acceptSidebarDrop([privateWindow.sidebarDrag(privateSecond,kind:.tab)],at:.beforeTab(privateFirst)) && privateWindow.state.visibleTabs.map(\.id)==[privateSecond,privateFirst])
        let privateOther=manager.newWindow(isPrivate:true)
        check("separate-private-store-rejected",!privateOther.acceptSidebarDrop([privatePayload],at:.beforeTab(privateOther.state.selectedTabID!)))
        privateOther.window?.close();privateWindow.window?.orderOut(nil)
        destination.openGlance(URL(string:"http://127.0.0.1:8765/index.html?drag-preview")!,from:moving)
        let preview=destination.state.activeGlance,previewView=preview.map{destination.runtime($0.id).webView}
        let returned=source.acceptSidebarDrop([destination.sidebarDrag(moving,kind:.tab)],at:.beforeTab(source.state.selectedTabID!))
        check("owner-drop-carries-live-preview",returned && preview != nil && source.state.activeGlance?.id==preview?.id && preview.map{source.runtimes[$0.id]?.loadedWebView === previewView}==true)
        let essential=destination.newTab(kind:.essential)
        check("different-category-rejected",!destination.acceptSidebarDrop([source.sidebarDrag(moving,kind:.tab)],at:.beforeTab(essential)) && source.runtimes[moving] === runtime)
        if let folder=destination.createFolder(name:"Dropped pages") {
            check("cross-window-folder-drop",destination.acceptSidebarDrop([source.sidebarDrag(moving,kind:.tab)],at:.folder(folder)) && destination.state.folderTabIDs(folder)==[moving] && destination.runtimes[moving] === runtime && destination.state.activeGlance?.id==preview?.id)
            check("cross-window-folder-tree-rejected",!source.acceptSidebarDrop([destination.sidebarDrag(folder,kind:.folder)],at:.beforeTab(source.state.selectedTabID!)))
            manager.saveNow()
            do {
                let saved=try SavedSession.decode(Data(contentsOf:manager.root.appendingPathComponent("session.json")))
                let state=saved.windows.first{$0.id==destination.state.id}
                check("membership-persists",state?.folderTabIDs(folder)==[moving] && state?.tabs.first{$0.id==moving}?.workspaceID==destination.state.activeWorkspaceID && !saved.windows.contains{$0.isPrivate})
            } catch{check("membership-persists",false,error.localizedDescription)}
        } else{check("folder-setup",false)}
        destination.window?.makeKeyAndOrderFront(nil)
        try? "51-cross-window-drag".write(to:root.appendingPathComponent("capture-request"),atomically:true,encoding:.utf8)
        await wait{FileManager.default.fileExists(atPath:root.appendingPathComponent("51-cross-window-drag.capture-finished").path)}
        runtime.hasUserEdits=false
        return results
    }
}
