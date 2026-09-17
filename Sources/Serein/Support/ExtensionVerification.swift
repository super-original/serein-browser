import Foundation
import WebKit
import SereinCore

@MainActor enum ExtensionVerification {
    static func run(manager:BrowserManager,session:BrowserSession) async -> [RuntimeVerification.Result] {
        var results:[RuntimeVerification.Result]=[]
        func check(_ name:String,_ passed:Bool,_ detail:String="") {results.append(.init(name:name,passed:passed,detail:detail))}
        for generation in [2,3] {
            let host=manager.extensions,id=UUID(),name="mv\(generation)"
            let source=Bundle.main.resourceURL!.appendingPathComponent("Fixtures/Extensions/"+name)
            let target=host.root.appendingPathComponent(id.uuidString)
            let key="sereinMV\(generation)"
            do {
                try FileManager.default.copyItem(at:source,to:target)
                let manifest=try ExtensionManifest(data:Data(contentsOf:target.appendingPathComponent("manifest.json")))
                let record=InstalledExtension(id:id,name:name,version:manifest.version,enabled:true,permissions:["storage","tabs"],hosts:[])
                try await host.load(record)
                session.navigate("http://127.0.0.1:8765/index.html?extension=\(name)-denied")
                try await Task.sleep(for:.seconds(2))
                let before=try await session.current!.webView.evaluateJavaScript("document.documentElement.dataset.\(key) || null")
                check("\(name)-host-permission-denied",before is NSNull)
                guard let context=host.contexts[id] else{throw ExtensionValidationError.invalid("No extension context")}
                for pattern in context.webExtension.requestedPermissionMatchPatterns {context.setPermissionStatus(.grantedExplicitly,for:pattern)}
                session.current!.webView.reload()
                var payload:[String:Any]?
                for _ in 0..<50 {
                    try await Task.sleep(for:.milliseconds(100))
                    if let value=try? await session.current!.webView.evaluateJavaScript("document.documentElement.dataset.\(key) || null"),let text=value as? String,let data=text.data(using:.utf8) {payload=(try? JSONSerialization.jsonObject(with:data)) as? [String:Any];break}
                }
                check("\(name)-background-message-storage-tabs",payload?["ok"] as? Bool==true && payload?["senderTab"] as? Bool==true && (payload?["tabCount"] as? Int ?? 0)>0,String(describing:payload))
                let secret=try await session.current!.webView.evaluateJavaScript("typeof window.sereinIsolatedSecret")
                check("\(name)-isolated-world",secret as? String=="undefined")
                let firstCount=payload?["count"] as? Int ?? 0
                try host.controller.unload(context);host.contexts[id]=nil
                var granted=record;granted.hosts=["http://127.0.0.1/*"]
                try await host.load(granted);session.current!.webView.reload()
                try await Task.sleep(for:.seconds(2))
                let value=try await session.current!.webView.evaluateJavaScript("document.documentElement.dataset.\(key) || null")
                let after=(value as? String).flatMap{$0.data(using:.utf8)}.flatMap{try? JSONSerialization.jsonObject(with:$0) as? [String:Any]}
                check("\(name)-storage-persists-reload",(after?["count"] as? Int ?? 0)>firstCount && firstCount>0)
                if let loaded=host.contexts[id] {try host.controller.unload(loaded);host.contexts[id]=nil}
                session.current!.webView.reload();try await Task.sleep(for:.seconds(1))
                let disabled=try await session.current!.webView.evaluateJavaScript("document.documentElement.dataset.\(key) || null")
                check("\(name)-disable-stops-injection",disabled is NSNull)
                try FileManager.default.removeItem(at:target)
            } catch {check("\(name)-lifecycle",false,error.localizedDescription);if let context=manager.extensions.contexts[id]{try? manager.extensions.controller.unload(context);manager.extensions.contexts[id]=nil}}
        }
        return results
    }
}
