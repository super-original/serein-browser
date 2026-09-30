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
                host.records.append(record)
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
                // Persist engine changes, including revocation, without depending on shutdown.
                guard let live=host.contexts[id] else{throw ExtensionValidationError.invalid("Missing reloaded context")}
                live.setPermissionStatus(.unknown,for:WKWebExtension.Permission(rawValue:"tabs"))
                host.setCurrentSite(id,in:session,allow:false)
                try await Task.sleep(for:.milliseconds(100))
                let saved=try JSONDecoder().decode([InstalledExtension].self,from:Data(contentsOf:host.root.appendingPathComponent("extensions.json")))
                guard let savedRecord=saved.first(where:{$0.id==id}),let savedState=savedRecord.permissionState else{throw ExtensionValidationError.invalid("Permission snapshot missing")}
                check("\(name)-permission-revocation-written",savedState.granted["tabs"] == nil && !savedState.deniedHosts.isEmpty)
                try host.controller.unload(live);host.contexts[id]=nil
                try await host.load(savedRecord)
                let restored=host.contexts[id]!
                let site=URL(string:"http://127.0.0.1:8765/index.html")!
                check("\(name)-permission-policy-restored",!restored.hasPermission(WKWebExtension.Permission(rawValue:"tabs")) && restored.permissionStatus(for:site) == .deniedExplicitly)
                session.current!.webView.reload();try await Task.sleep(for:.seconds(1))
                let revoked=try await session.current!.webView.evaluateJavaScript("document.documentElement.dataset.\(key) || null")
                check("\(name)-restored-denial-stops-injection",revoked is NSNull)
                await host.setEnabled(id,false)
                check("\(name)-disable-record",host.records.first{$0.id==id}?.enabled == false && host.contexts[id] == nil)
                session.current!.webView.reload();try await Task.sleep(for:.seconds(1))
                let disabled=try await session.current!.webView.evaluateJavaScript("document.documentElement.dataset.\(key) || null")
                check("\(name)-disable-stops-injection",disabled is NSNull)
                await host.remove(id)
                let remaining=await host.controller.dataRecords(ofTypes:WKWebExtensionController.allExtensionDataTypes.subtracting([.session]))
                check("\(name)-remove-disabled-data-errors",remaining.filter{$0.uniqueIdentifier==id.uuidString}.allSatisfy{$0.errors.isEmpty},"WebKit can retain an empty metadata record after removing storage.")
                check("\(name)-remove-package-and-record",!FileManager.default.fileExists(atPath:target.path) && !host.records.contains{$0.id==id},host.error ?? "")
                guard !FileManager.default.fileExists(atPath:target.path) else {throw ExtensionValidationError.invalid(host.error ?? "Removal left package installed") }
                // Metadata presence is not stored-value persistence. Reinstall with
                // the same identity and prove the old storage counter is gone.
                try FileManager.default.copyItem(at:source,to:target)
                try await host.load(granted);host.records.append(granted)
                session.current!.webView.reload()
                var resetCount:Int?
                for _ in 0..<50 {
                    try await Task.sleep(for:.milliseconds(100))
                    if let value=try? await session.current!.webView.evaluateJavaScript("document.documentElement.dataset.\(key) || null"),let text=value as? String,let data=text.data(using:.utf8),let payload=(try? JSONSerialization.jsonObject(with:data)) as? [String:Any] {
                        resetCount=payload["count"] as? Int;break
                    }
                }
                check("\(name)-remove-erases-stored-value",resetCount==1,"Counter after reinstall with identical UUID: \(String(describing:resetCount))")
                await host.remove(id)
            } catch {check("\(name)-lifecycle",false,error.localizedDescription);if let context=manager.extensions.contexts[id]{try? manager.extensions.controller.unload(context);manager.extensions.contexts[id]=nil}}
        }
        return results
    }
}
