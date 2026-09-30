import AppKit
import WebKit
import SereinCore

@MainActor enum FolderVerification {
    static func run(manager:BrowserManager,root:URL) async -> [RuntimeVerification.Result] {
        var results:[RuntimeVerification.Result]=[]
        let session=manager.newWindow();defer{session.window?.close()}
        func check(_ name:String,_ passed:Bool,_ detail:String=""){results.append(.init(name:"folders-"+name,passed:passed,detail:detail))}
        func wait(_ condition:@MainActor ()->Bool) async {
            for _ in 0..<160 {if condition(){return};try? await Task.sleep(for:.milliseconds(50))}
        }
        func keyboard(_ name:String) async -> Bool {
            let done=root.appendingPathComponent(name+".keyboard-finished"),failed=root.appendingPathComponent(name+".keyboard-failed")
            try? FileManager.default.removeItem(at:done);try? FileManager.default.removeItem(at:failed)
            try? name.write(to:root.appendingPathComponent("keyboard-request"),atomically:true,encoding:.utf8)
            await wait{FileManager.default.fileExists(atPath:done.path)}
            return FileManager.default.fileExists(atPath:done.path) && !FileManager.default.fileExists(atPath:failed.path)
        }
        func capture(_ name:String) async {
            try? name.write(to:root.appendingPathComponent("capture-request"),atomically:true,encoding:.utf8)
            await wait{FileManager.default.fileExists(atPath:root.appendingPathComponent(name+".capture-finished").path)}
            check("capture-"+name,FileManager.default.fileExists(atPath:root.appendingPathComponent(name+".png").path))
        }
        session.window?.setFrame(NSRect(x:10,y:61,width:1000,height:677),display:true)
        if let essential=session.state.selectedTabID {session.setKind(essential,.essential)}
        session.addWorkspace(name:"Folder reference")
        let empty=session.state.selectedTabID!
        let a=session.newTab(url:"http://127.0.0.1:8765/index.html"),b=session.newTab(url:"http://127.0.0.1:8765/second.html",select:false)
        session.close(empty,ask:false)
        let first=session.runtime(a),second=session.runtime(b);_=second.webView
        await wait{first.webView.title=="Field Notes" && second.webView.title=="Second Field Note"}
        session.folderEditor = .init(tabIDs:[a,b],name:"")
        await wait{session.window?.attachedSheet != nil}
        let created=await keyboard("folder-name")
        await wait{session.folderEditor==nil}
        guard let folder=session.state.folders?.first(where:{$0.name=="Research notes"}) else {check("native-editor-creates-folder",false,"Actual name entry did not create folder");return results}
        check("native-editor-creates-folder",created && session.state.folderTabIDs(folder.id)==[a,b] && session.state.tabs.filter{[a,b].contains($0.id)}.allSatisfy{$0.kind == .pinned})
        check("grouping-retains-live-webviews",session.runtime(a)===first && session.runtime(b)===second)
        await capture("44-folder-expanded")
        let collapsed=await keyboard("folder-toggle")
        await wait{session.state.folder(folder.id)?.collapsed==true}
        check("accessible-button-collapses",collapsed && session.state.folder(folder.id)?.collapsed==true)
        check("collapse-retains-active-child",session.state.pinnedSidebarRows.map(\.id)==[folder.id,a])
        await capture("45-folder-collapsed")
        session.select(b)
        check("selection-reveals-collapsed-child",session.state.pinnedSidebarRows.map(\.id)==[folder.id,b] && session.current===second)
        _=await keyboard("folder-toggle")
        await wait{session.state.folder(folder.id)?.collapsed==false}
        let child=session.createFolder(name:"Reading list",parentID:folder.id)
        if let child {for _ in 0..<2 {_=session.state.shiftPinnedItem(child,by:-1)}}
        session.select(a)
        check("nested-folder",child.flatMap{session.state.folder($0)?.parentID}==folder.id)
        await capture("46-folder-nested")
        session.state.renameFolder(folder.id,to:"Research archive")
        manager.saveNow()
        do {
            let restored=try SavedSession.decode(Data(contentsOf:manager.root.appendingPathComponent("session.json")))
            let window=restored.windows.first{$0.id==session.state.id}
            check("session-persists-membership-and-name",window?.folder(folder.id)?.name=="Research archive" && window?.folderTabIDs(folder.id)==[a,b] && child.flatMap{window?.folder($0)?.parentID}==folder.id)
        } catch {check("session-persists-membership-and-name",false,error.localizedDescription)}
        session.deleteFolder(folder.id)
        await wait{session.window?.attachedSheet != nil}
        if let sheet=session.window?.attachedSheet {session.window?.endSheet(sheet,returnCode:.alertSecondButtonReturn)}
        await wait{session.window?.attachedSheet==nil}
        check("delete-cancel-keeps-pages",session.state.folder(folder.id) != nil && session.state.folderTabIDs(folder.id)==[a,b] && session.runtime(a)===first)
        session.deleteFolder(folder.id)
        await wait{session.window?.attachedSheet != nil}
        let extra=session.newTab(select:false);session.moveTabIntoFolder(extra,folder.id)
        if let sheet=session.window?.attachedSheet {session.window?.endSheet(sheet,returnCode:.alertFirstButtonReturn)}
        await wait{session.window?.attachedSheet==nil}
        check("membership-change-invalidates-delete-consent",session.state.folder(folder.id) != nil && session.state.tabs.contains{$0.id==a})
        session.close(extra,ask:false)
        session.deleteFolder(folder.id)
        await wait{session.window?.attachedSheet != nil}
        first.load(URL(string:"http://127.0.0.1:8765/index.html?folder-document-change=1")!)
        if let sheet=session.window?.attachedSheet {session.window?.endSheet(sheet,returnCode:.alertFirstButtonReturn)}
        await wait{session.window?.attachedSheet==nil}
        check("document-change-invalidates-delete-consent",session.state.folder(folder.id) != nil && session.state.tabs.contains{$0.id==a})
        session.state.unpackFolder(folder.id)
        check("unpack-keeps-tabs-and-subfolder",session.state.folder(folder.id)==nil && session.state.tabs.contains{$0.id==a} && session.state.tabs.contains{$0.id==b} && child.flatMap{session.state.folder($0)} != nil && session.runtime(a)===first)
        let deleting=session.createFolder(name:"Delete fixture",tabIDs:[a,b])!
        session.deleteFolder(deleting)
        await wait{session.window?.attachedSheet != nil}
        if let sheet=session.window?.attachedSheet {session.window?.endSheet(sheet,returnCode:.alertFirstButtonReturn)}
        await wait{session.state.folder(deleting)==nil}
        check("fresh-consent-closes-only-folder-pages",session.state.folder(deleting)==nil && !session.state.tabs.contains{[a,b].contains($0.id)} && child.flatMap{session.state.folder($0)} != nil && session.runtimes[a]==nil && session.runtimes[b]==nil)
        return results
    }
}
