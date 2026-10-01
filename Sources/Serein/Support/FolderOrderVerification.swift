import AppKit
import WebKit
import SereinCore

@MainActor enum FolderOrderVerification {
    static func run(manager:BrowserManager,root:URL) async->[RuntimeVerification.Result] {
        var results:[RuntimeVerification.Result]=[]
        func check(_ name:String,_ pass:Bool,_ detail:String="") {results.append(.init(name:"folder-order-"+name,passed:pass,detail:detail))}
        func wait(_ condition:@MainActor ()->Bool) async {for _ in 0..<160 {if condition(){return};try? await Task.sleep(for:.milliseconds(50))}}
        let session=manager.newWindow();defer{session.window?.close()}
        session.window?.setFrame(NSRect(x:10,y:61,width:1000,height:677),display:true)
        let tab=session.state.selectedTabID!,runtime=session.runtime(tab),view=runtime.webView
        runtime.load(URL(string:"http://127.0.0.1:8765/index.html?folder-order")!)
        await wait{view.title=="Field Notes" && !view.isLoading}
        let first=session.createFolder(name:"Research",tabIDs:[tab])!,last=session.createFolder(name:"Reading")!
        session.state.folders?[0].userIcon=FolderIcon.science.rawValue
        let nested=session.createFolder(name:"Sources",parentID:first)!
        session.state.toggleFolder(first)
        session.window?.makeKeyAndOrderFront(nil)
        func drag(_ name:String,source:UUID,target:UUID) async ->Bool {
            let done=root.appendingPathComponent(name+".keyboard-finished")
            try? "folder-\(source)\nfolder-\(target)\n".write(to:root.appendingPathComponent("sidebar-drag-identifiers"),atomically:true,encoding:.utf8)
            try? name.write(to:root.appendingPathComponent("keyboard-request"),atomically:true,encoding:.utf8)
            await wait{FileManager.default.fileExists(atPath:done.path)}
            return FileManager.default.fileExists(atPath:done.path) && !FileManager.default.fileExists(atPath:root.appendingPathComponent(name+".keyboard-failed").path)
        }
        let after=await drag("sidebar-folder-after",source:first,target:last)
        await wait{session.state.pinnedItemIDs()==[last,first]}
        check("actual-pointer-after-last-folder",after && session.state.pinnedItemIDs()==[last,first])
        let before=await drag("sidebar-folder-before",source:first,target:last)
        await wait{session.state.pinnedItemIDs()==[first,last]}
        check("actual-pointer-before-folder",before && session.state.pinnedItemIDs()==[first,last])
        check("reordering-preserves-tree-icon-and-live-document",session.state.folder(nested)?.parentID==first && session.state.folder(first)?.resolvedIcon == .science && session.state.folder(first)?.collapsed==true && session.runtime(tab)===runtime && runtime.loadedWebView===view && session.state.selectedTabID==tab)
        let payload=session.sidebarDrag(first,kind:.folder),saved=session.state
        check("descendant-placement-rejected-atomically",!session.acceptSidebarDrop([payload],at:.afterFolder(nested)) && session.state==saved)
        let forged=SidebarDragItem(token:UUID(),window:session.state.id,item:first,kind:.folder)
        check("foreign-token-placement-rejected",!session.acceptSidebarDrop([forged],at:.beforeFolder(last)) && session.state==saved)
        let other=manager.newWindow();defer{other.window?.close()}
        let otherFolder=other.createFolder(name:"Other")!,otherState=other.state
        check("cross-window-folder-placement-rejected",!other.acceptSidebarDrop([payload],at:.beforeFolder(otherFolder)) && other.state==otherState && session.state==saved)
        other.window?.orderOut(nil);session.window?.makeKeyAndOrderFront(nil)
        manager.saveNow()
        do {
            let restored=try SavedSession.decode(Data(contentsOf:manager.root.appendingPathComponent("session.json")))
            check("native-order-persists",restored.windows.first{$0.id==session.state.id}?.pinnedItemIDs()==[first,last])
        } catch {check("native-order-persists",false,error.localizedDescription)}
        let capture="70-folder-reordered"
        try? capture.write(to:root.appendingPathComponent("capture-request"),atomically:true,encoding:.utf8)
        await wait{FileManager.default.fileExists(atPath:root.appendingPathComponent(capture+".capture-finished").path)}
        check("capture",FileManager.default.fileExists(atPath:root.appendingPathComponent(capture+".png").path))
        return results
    }
}
