import AppKit
import WebKit
import SereinCore

@MainActor enum BookmarkVerification {
    static func run(manager:BrowserManager,root:URL) async -> [RuntimeVerification.Result] {
        var results:[RuntimeVerification.Result]=[]
        func check(_ name:String,_ passed:Bool,_ detail:String="") {results.append(.init(name:"bookmark-editor-"+name,passed:passed,detail:detail))}
        func wait(_ condition:@MainActor ()->Bool) async -> Bool {
            for _ in 0..<100 {if condition(){return true};try? await Task.sleep(for:.milliseconds(100))}
            return false
        }
        func keyboard(_ name:String) async -> Bool {
            let done=root.appendingPathComponent(name+".keyboard-finished"),failed=root.appendingPathComponent(name+".keyboard-failed")
            try? FileManager.default.removeItem(at:done);try? FileManager.default.removeItem(at:failed)
            try? name.write(to:root.appendingPathComponent("keyboard-request"),atomically:true,encoding:.utf8)
            let finished=await wait{FileManager.default.fileExists(atPath:done.path)}
            return finished && !FileManager.default.fileExists(atPath:failed.path)
        }
        func capture(_ name:String) async -> Bool {
            try? name.write(to:root.appendingPathComponent("capture-request"),atomically:true,encoding:.utf8)
            return await wait{FileManager.default.fileExists(atPath:root.appendingPathComponent(name+".capture-finished").path)}
        }
        let session=manager.newWindow(),store=manager.library
        let initialURL="http://127.0.0.1:8765/index.html?bookmark-edit=original"
        defer {
            for record in store.bookmarks where record.url==initialURL || record.url=="http://127.0.0.1:8765/second.html?bookmark-edit=updated" {store.removeBookmark(record.id)}
            session.window?.close()
        }
        session.navigate(initialURL,ask:false)
        _=await wait{session.current?.webView.title=="Field Notes"}
        let runtime=session.current
        session.window?.makeKeyAndOrderFront(nil)
        let create=await keyboard("bookmark-open")
        let visible=await wait{session.bookmarkEditor != nil && session.window?.attachedSheet != nil}
        check("command-opens-draft",create && visible && !store.bookmarks.contains{$0.url==initialURL})
        guard visible else{return results}
        check("create-sheet-captured",await capture("72-bookmark-create"))
        let saved=await keyboard("bookmark-title-save")
        _=await wait{session.bookmarkEditor==nil && session.window?.attachedSheet==nil}
        guard let record=store.bookmarks.first(where:{$0.url==initialURL}) else{check("native-save",false);return results}
        check("native-save",saved && record.title=="Research bookmark")
        let reopened=await keyboard("bookmark-open")
        _=await wait{session.bookmarkEditor?.original?.id==record.id && session.window?.attachedSheet != nil}
        let typed=await keyboard("bookmark-title-cancelled")
        let cancelled=await keyboard("bookmark-cancel")
        _=await wait{session.bookmarkEditor==nil && session.window?.attachedSheet==nil}
        check("cancel-preserves-existing",reopened && typed && cancelled && store.bookmarks.first(where:{$0.id==record.id})==record)
        session.libraryPanel = .bookmarks
        _=await wait{session.window?.attachedSheet != nil}
        try? "bookmark-edit-\(record.id)".write(to:root.appendingPathComponent("bookmark-edit-identifier"),atomically:true,encoding:.utf8)
        let edit=await keyboard("bookmark-library-edit")
        let editSheet=await wait{session.dialogWindow?.attachedSheet != nil}
        check("library-edit-control",edit && editSheet)
        if editSheet {
            let changed=await keyboard("bookmark-url-save")
            _=await wait{session.dialogWindow?.attachedSheet==nil}
            let updated=store.bookmarks.first{$0.id==record.id}
            let restored=LibraryStore(root:store.root)
            check("address-edit-persists-same-id",changed && updated?.url=="http://127.0.0.1:8765/second.html?bookmark-edit=updated" && updated?.date==record.date && restored.bookmarks.first(where:{$0.id==record.id})==updated)
            check("updated-library-captured",await capture("73-bookmark-updated"))
        }
        session.libraryPanel=nil
        _=await wait{session.window?.attachedSheet==nil}
        check("editing-preserves-live-page",session.current===runtime && session.current?.webView.url?.absoluteString==initialURL)
        return results
    }
}
