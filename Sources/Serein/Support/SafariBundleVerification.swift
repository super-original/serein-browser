import AppKit
import WebKit
import SereinCore

@MainActor enum SafariBundleVerification {
    static func run(manager:BrowserManager,root:URL) async -> [RuntimeVerification.Result] {
        var results:[RuntimeVerification.Result]=[]
        let host=manager.extensions,session=manager.newWindow()
        defer{session.window?.close()}
        func check(_ name:String,_ passed:Bool,_ detail:String=""){results.append(.init(name:"safari-bundle-"+name,passed:passed,detail:detail))}
        func wait(_ condition:@MainActor ()->Bool) async {
            for _ in 0..<160 {if condition(){return};try? await Task.sleep(for:.milliseconds(50))}
        }
        let source=Bundle.main.resourceURL!.appendingPathComponent("Fixtures/SafariWebExtension.appex")
        let before=Set(host.records.map(\.id))
        for approve in [false,true] {
            var finished=false
            let installation=Task{await host.install(source,in:session);finished=true}
            await wait{session.window?.attachedSheet != nil || finished}
            let presented=session.window?.attachedSheet != nil
            check(approve ? "installation-review" : "installation-cancel-review",presented,host.error ?? "")
            if approve,presented {
                let name="49-safari-bundle-installation"
                try? name.write(to:root.appendingPathComponent("capture-request"),atomically:true,encoding:.utf8)
                await wait{FileManager.default.fileExists(atPath:root.appendingPathComponent(name+".capture-finished").path)}
                check("capture-installation-review",FileManager.default.fileExists(atPath:root.appendingPathComponent(name+".png").path))
            }
            if let sheet=session.window?.attachedSheet {session.window?.endSheet(sheet,returnCode:approve ? .alertFirstButtonReturn : .alertSecondButtonReturn)}
            await installation.value
            if !approve {check("cancel-keeps-package-uninstalled",Set(host.records.map(\.id))==before)}
        }
        guard let record=host.records.first(where:{!before.contains($0.id)}),let context=host.contexts[record.id],let options=context.optionsPageURL else {
            check("installed-context",false,host.error ?? "No installed Safari fixture");return results
        }
        do {
            let installed=record.directory(in:host.root)
            check("bundle-manifest-preserved",try Data(contentsOf:source.appendingPathComponent("Contents/Resources/manifest.json"))==Data(contentsOf:installed.appendingPathComponent("Contents/Resources/manifest.json")))
            let tab=session.newTab(url:options.absoluteString),runtime=session.runtime(tab)
            await wait{runtime.webView.title=="Safari bundle fixture" && !runtime.webView.isLoading}
            check("options-load",runtime.webView.title=="Safari bundle fixture")
            func roundtrip() async throws -> [String:Any]? {
                try await runtime.webView.callAsyncJavaScript("return await browser.runtime.sendMessage({operation:'roundtrip',value:'Safari bundle 雪'});",arguments:[:],in:nil,contentWorld:.page) as? [String:Any]
            }
            let first=try await roundtrip()
            check("worker-message-and-storage",first?["count"] as? Int==1 && first?["value"] as? String=="Safari bundle 雪",String(describing:first))
            await host.setEnabled(record.id,false)
            check("disable-unloads-context",host.contexts[record.id]==nil)
            await host.setEnabled(record.id,true)
            await wait{runtime.loadedWebView?.title=="Safari bundle fixture" && runtime.loadedWebView?.isLoading==false}
            let second=try await roundtrip()
            check("reload-preserves-storage-and-identity",second?["count"] as? Int==2 && second?["id"] as? String==first?["id"] as? String,String(describing:second))
            let tampered=root.appendingPathComponent("tampered-safari.appex")
            try FileManager.default.copyItem(at:source,to:tampered)
            defer{try? FileManager.default.removeItem(at:tampered)}
            let manifest=tampered.appendingPathComponent("Contents/Resources/manifest.json")
            var bytes=try Data(contentsOf:manifest);bytes.append(0x20);try bytes.write(to:manifest)
            do {
                let invalid=try await ExtensionPackageLoader.load(tampered)
                check("tampered-bundle-rejected",!invalid.errors.isEmpty,invalid.errors.map(\.localizedDescription).joined(separator:"; "))
            } catch {check("tampered-bundle-rejected",true,error.localizedDescription)}
            await host.remove(record.id)
            check("remove-cleans-package-and-context",host.contexts[record.id]==nil && !host.records.contains{$0.id==record.id} && !FileManager.default.fileExists(atPath:installed.path))
        } catch {check("scenario",false,error.localizedDescription);await host.remove(record.id)}
        return results
    }
}
