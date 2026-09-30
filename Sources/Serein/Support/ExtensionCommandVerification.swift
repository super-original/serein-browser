import AppKit
import WebKit

@MainActor enum ExtensionCommandVerification {
    static func run(manager:BrowserManager,session:BrowserSession,context:WKWebExtensionContext,name:String,root:URL) async -> [RuntimeVerification.Result] {
        var results:[RuntimeVerification.Result]=[]
        func check(_ suffix:String,_ passed:Bool,_ detail:String=""){results.append(.init(name:name+"-command-"+suffix,passed:passed,detail:detail))}
        guard let configuration=context.webViewConfiguration else{return [.init(name:name+"-command-setup",passed:false,detail:"No extension page configuration")]}
        let view=WKWebView(frame:.zero,configuration:configuration)
        defer{view.stopLoading()}
        view.load(context.baseURL.appendingPathComponent("popup.html"))
        for _ in 0..<50 {
            if view.title=="Fixture popup",!view.isLoading{break}
            try? await Task.sleep(for:.milliseconds(100))
        }
        func count() async -> Int? {
            try? await view.callAsyncJavaScript("return (await browser.storage.local.get('commandCount')).commandCount || 0",arguments:[:],in:nil,contentWorld:.page) as? Int
        }
        func press() async -> Bool {
            let marker=root.appendingPathComponent("extension-command.keyboard-finished")
            try? FileManager.default.removeItem(at:marker)
            try? "extension-command".write(to:root.appendingPathComponent("keyboard-request"),atomically:true,encoding:.utf8)
            for _ in 0..<100 {
                if FileManager.default.fileExists(atPath:marker.path){return true}
                try? await Task.sleep(for:.milliseconds(100))
            }
            return false
        }
        session.window?.makeKeyAndOrderFront(nil)
        let before=await count()
        let pressed=await press()
        var after:Int?
        for _ in 0..<50 {
            after=await count()
            if let before,after==before+1{break}
            try? await Task.sleep(for:.milliseconds(100))
        }
        check("native-key-delivers-once",pressed && before != nil && after==before.map{$0+1},"before=\(String(describing:before)) after=\(String(describing:after))")
        var menuCount=after
        if let id=manager.extensions.contexts.first(where:{$0.value===context})?.key {
            session.libraryPanel = .extensions
            try? await Task.sleep(for:.milliseconds(250))
            let performed=await manager.extensions.performCommandFromLibrary(id,commandID:"record-fixture-command",in:session)
            for _ in 0..<50 {
                menuCount=await count()
                if let after,menuCount==after+1{break}
                try? await Task.sleep(for:.milliseconds(100))
            }
            check("management-command-dismisses-sheet",performed && session.window?.attachedSheet==nil && after != nil && menuCount==after.map{$0+1})
        } else {check("management-command-context",false)}
        let privateSession=manager.newWindow(isPrivate:true)
        let privatePressed=await press()
        try? await Task.sleep(for:.milliseconds(400))
        let privateCount=await count()
        check("private-window-does-not-dispatch",privatePressed && menuCount != nil && privateCount==menuCount)
        privateSession.window?.close();session.window?.makeKeyAndOrderFront(nil)
        return results
    }
}
