import AppKit
import WebKit

@MainActor enum PageSnapshotVerification {
    static func run(manager:BrowserManager,root:URL) async->[RuntimeVerification.Result] {
        var results:[RuntimeVerification.Result]=[]
        func check(_ name:String,_ pass:Bool,_ detail:String=""){results.append(.init(name:"page-snapshot-"+name,passed:pass,detail:detail))}
        func wait(_ condition:@MainActor ()->Bool) async->Bool {
            for _ in 0..<150{if condition(){return true};try? await Task.sleep(for:.milliseconds(100))};return false
        }
        let previous=manager.active,session=manager.newWindow(),id=session.state.selectedTabID!
        defer{session.window?.close();previous?.window?.makeKeyAndOrderFront(nil)}
        session.navigate("http://127.0.0.1:8765/index.html?snapshot=1")
        _=await wait{session.current?.title=="Field Notes" && PageSnapshot.available(in:session)}
        do {
            let capture=try await PageSnapshot.capture(in:session)
            let bitmap=NSBitmapImageRep(data:capture.png)
            check("viewport-png",capture.png.starts(with:[137,80,78,71,13,10,26,10]) && (bitmap?.pixelsWide ?? 0)>500 && (bitmap?.pixelsHigh ?? 0)>400)
            let other=session.newTab()
            check("selection-invalidates-capture",!capture.isCurrent(in:session))
            session.select(id);session.close(other,ask:false)
            session.navigate("http://127.0.0.1:8765/second.html?snapshot=2")
            _=await wait{session.current?.title=="Second Field Note" && !session.current!.isLoading}
            check("navigation-invalidates-capture",!capture.isCurrent(in:session))
            session.navigate("http://127.0.0.1:8765/index.html?snapshot=3")
            _=await wait{session.current?.title=="Field Notes" && PageSnapshot.available(in:session)}
            try "open-page-screenshot".write(to:root.appendingPathComponent("keyboard-request"),atomically:true,encoding:.utf8)
            let cancelPresented=await wait{session.window?.attachedSheet is NSSavePanel}
            check("native-menu-command",cancelPresented && session.savingPageSnapshot)
            check("cancel-sheet-and-duplicate-refusal",cancelPresented && !PageSnapshot.available(in:session))
            (session.window?.attachedSheet as? NSSavePanel)?.cancel(nil)
            _=await wait{!session.savingPageSnapshot}
            check("cancel-without-output",session.error==nil && !session.savingPageSnapshot && !FileManager.default.fileExists(atPath:root.appendingPathComponent("native-page-screenshot.png").path))
            let saved=Task{try await PageSnapshot.save(in:session)}
            let presented=await wait{session.window?.attachedSheet is NSSavePanel}
            check("save-sheet",presented)
            if presented {
                try "prepare-save-snapshot".write(to:root.appendingPathComponent("keyboard-request"),atomically:true,encoding:.utf8)
                _=await wait{FileManager.default.fileExists(atPath:root.appendingPathComponent("prepare-save-snapshot.keyboard-finished").path)}
                try "58-page-screenshot-save".write(to:root.appendingPathComponent("capture-request"),atomically:true,encoding:.utf8)
                let captured=await wait{FileManager.default.fileExists(atPath:root.appendingPathComponent("58-page-screenshot-save.capture-finished").path)}
                check("save-sheet-capture",captured)
                try "save-snapshot".write(to:root.appendingPathComponent("keyboard-request"),atomically:true,encoding:.utf8)
                _=await wait{!session.savingPageSnapshot}
                if session.savingPageSnapshot{(session.window?.attachedSheet as? NSSavePanel)?.cancel(nil)}
            }
            let output=try await saved.value
            let expected=root.appendingPathComponent("native-page-screenshot.png")
            check("native-save-destination",output?.resolvingSymlinksInPath()==expected.resolvingSymlinksInPath(),String(describing:output))
            let data=try? Data(contentsOf:expected)
            check("native-save-valid-png",data.flatMap{NSBitmapImageRep(data:$0)}?.pixelsWide==bitmap?.pixelsWide && data?.starts(with:[137,80,78,71,13,10,26,10])==true)
            check("menu-restored",PageSnapshot.available(in:session))
            let privateSession=manager.newWindow(isPrivate:true)
            defer{privateSession.window?.close()}
            privateSession.navigate("http://127.0.0.1:8765/index.html?snapshot=private")
            _=await wait{privateSession.current?.title=="Field Notes" && PageSnapshot.available(in:privateSession)}
            let privateSave=Task{try await PageSnapshot.save(in:privateSession)}
            _=await wait{privateSession.window?.attachedSheet is NSSavePanel}
            let privatePanel=privateSession.window?.attachedSheet as? NSSavePanel
            check("private-explicit-disk-warning",privatePanel?.message.contains("private page content to disk")==true)
            privatePanel?.cancel(nil)
            check("private-cancel",try await privateSave.value==nil)
            let finalCapture=try await PageSnapshot.capture(in:privateSession)
            privateSession.window?.close()
            check("window-close-invalidates-capture",!finalCapture.isCurrent(in:privateSession))
        } catch {check("operation",false,error.localizedDescription)}
        return results
    }
}
