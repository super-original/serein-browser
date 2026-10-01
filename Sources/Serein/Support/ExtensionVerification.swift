import AppKit
import WebKit
import SereinCore

@MainActor enum ExtensionVerification {
    static func run(manager:BrowserManager,session:BrowserSession,root:URL) async -> [RuntimeVerification.Result] {
        var results:[RuntimeVerification.Result]=[]
        func check(_ name:String,_ passed:Bool,_ detail:String="") {results.append(.init(name:name,passed:passed,detail:detail));print("EXT_VERIFY \(name): \(passed)");fflush(stdout)}
        for generation in [2,3] {
            let host=manager.extensions,id=UUID(),name="mv\(generation)"
            let source=Bundle.main.resourceURL!.appendingPathComponent("Fixtures/Extensions/"+name)
            let target=host.root.appendingPathComponent(id.uuidString)
            let key="sereinMV\(generation)"
            do {
                try host.prepare(source,at:target)
                let manifest=try ExtensionManifest(data:Data(contentsOf:target.appendingPathComponent("manifest.json")))
                let record=InstalledExtension(id:id,name:name,version:manifest.version,enabled:true,permissions:["storage","tabs"],hosts:[])
                try await host.load(record)
                host.records.append(record)
                let sleeping=session.newTab(url:"http://127.0.0.1:8765/index.html?sleeping",select:false)
                session.navigate("http://127.0.0.1:8765/index.html?extension=\(name)-denied")
                try await Task.sleep(for:.seconds(2))
                let before=try await session.current!.webView.evaluateJavaScript("document.documentElement.dataset.\(key) || null")
                check("\(name)-host-permission-denied",before is NSNull)
                guard let context=host.contexts[id] else{throw ExtensionValidationError.invalid("No extension context")}
                check("\(name)-declared-action-available",host.hasAction(id) && host.actionEnabled(id,in:session))
                check("\(name)-resource-origin-scheme",context.baseURL.scheme=="webkit-extension","Default resource origins; custom Firefox origin is isolated in a separate process")
                results += await ExtensionSenderVerification.resourcePage(session:session,context:context,name:name)
                results += await ExtensionWindowCloseVerification.run(manager:manager,context:context,name:name)
                for pattern in context.webExtension.requestedPermissionMatchPatterns {context.setPermissionStatus(.grantedExplicitly,for:pattern)}
                session.current!.webView.reload()
                var payload:[String:Any]?
                for _ in 0..<50 {
                    try await Task.sleep(for:.milliseconds(100))
                    if let value=try? await session.current!.webView.evaluateJavaScript("document.documentElement.dataset.\(key) || null"),let text=value as? String,let data=text.data(using:.utf8) {payload=(try? JSONSerialization.jsonObject(with:data)) as? [String:Any];break}
                }
                check("\(name)-background-message-storage-tabs",payload?["ok"] as? Bool==true && payload?["senderTab"] as? Bool==true && (payload?["tabCount"] as? Int ?? 0)>0,String(describing:payload))
                results += await ExtensionCommandVerification.run(manager:manager,session:session,context:context,name:name,root:root)
                check("\(name)-tabs-query-keeps-unloaded-tab-asleep",session.runtimes[sleeping]==nil)
                session.close(sleeping,ask:false)
                let lifecycle=payload?["tabLifecycle"] as? [String:Bool]
                for field in ["openerCreated","openerDuplicated","openerUpdated","selfOpenerRejected","creationIndex","createdEventProperties","zoomSet","zoomReset","zoomEvent","createdPinned","duplicatePinned","distinctIDs","duplicateURL","createdEvents","removedEvents","multiSelected","firstHighlightActive","highlightedEvent"] {
                    check("\(name)-tabs-\(field)",lifecycle?[field] == true,String(describing:lifecycle)+" selection="+String(describing:payload?["selectionDiagnostics"]))
                }
                check("\(name)-windows-tabs-permission-granted",context.hasPermission(WKWebExtension.Permission(rawValue:"tabs")),"about:blank permission status=\(context.permissionStatus(for:URL(string:"about:blank")!).rawValue)")
                let windowLifecycle=payload?["windowLifecycle"] as? [String:Any]
                for field in ["crossWindowOpenerRejected","normalWindow","initialBounds","populatedTabs","grantedPopulatedURL","resized","focused","removed","privateRejected","createdEvent","removedEvent"] {
                    check("\(name)-windows-\(field)",windowLifecycle?[field] as? Bool==true,String(describing:windowLifecycle))
                }
                let secret=try await session.current!.webView.evaluateJavaScript("typeof window.sereinIsolatedSecret")
                check("\(name)-isolated-world",secret as? String=="undefined")
                if name=="mv3" {
                    let world=try? await session.current!.webView.evaluateJavaScript("({marker:document.documentElement.dataset.sereinMainWorldMarker || '',global:window.sereinMainWorldProbe || '',order:document.documentElement.dataset.sereinMainWorldObservedEnd || '',endNow:document.documentElement.dataset.sereinDocumentEndMarker || ''})") as? [String:String]
                    check("mv3-main-world-script-executes",world?["marker"]=="executed",String(describing:world))
                    check("mv3-main-world-global-visible",world?["global"]=="page-global",String(describing:world))
                    check("mv3-document-idle-follows-end-across-worlds",world?["order"]=="ready" && world?["endNow"]=="ready",String(describing:world))
                }
                results += await ExtensionSplitGroupVerification.run(manager:manager,context:context,name:name)
                results += await ExtensionFrameVerification.run(session:session,generation:generation)
                results += await ExtensionResourceVerification.run(context:context,session:session,generation:generation)
                let firstCount=payload?["count"] as? Int ?? 0
                try host.controller.unload(context);host.contexts[id]=nil
                var granted=record;granted.hosts=["http://127.0.0.1/*"]
                try await host.load(granted);session.current!.webView.reload()
                var after:[String:Any]?
                for _ in 0..<80 {
                    try await Task.sleep(for:.milliseconds(100))
                    let value=try? await session.current!.webView.evaluateJavaScript("document.documentElement.dataset.\(key) || null")
                    after=(value as? String).flatMap{$0.data(using:.utf8)}.flatMap{try? JSONSerialization.jsonObject(with:$0) as? [String:Any]}
                    if after?["ok"] as? Bool==true,(after?["count"] as? Int ?? 0)>firstCount{break}
                }
                check("\(name)-storage-persists-reload",(after?["count"] as? Int ?? 0)>firstCount && firstCount>0)
                if generation == 3 {
                    session.libraryPanel = .extensions
                    try await Task.sleep(for:.milliseconds(500))
                    let capture="16-extension-management"
                    try capture.write(to:root.appendingPathComponent("capture-request"),atomically:true,encoding:.utf8)
                    for _ in 0..<100 {
                        if FileManager.default.fileExists(atPath:root.appendingPathComponent(capture+".capture-finished").path) {break}
                        try await Task.sleep(for:.milliseconds(100))
                    }
                    check("extension-management-capture",FileManager.default.fileExists(atPath:root.appendingPathComponent(capture+".png").path))
                    let librarySheet=session.window?.attachedSheet
                    host.confirmRemoval(record,in:session)
                    try await Task.sleep(for:.milliseconds(300))
                    let removalSheet=librarySheet?.attachedSheet
                    check("extension-remove-dialog-visible",librarySheet != nil && removalSheet != nil)
                    if let removalSheet {
                        let name="17-extension-removal-confirmation"
                        try name.write(to:root.appendingPathComponent("capture-request"),atomically:true,encoding:.utf8)
                        for _ in 0..<100 {
                            if FileManager.default.fileExists(atPath:root.appendingPathComponent(name+".capture-finished").path){break}
                            try await Task.sleep(for:.milliseconds(100))
                        }
                        check("extension-remove-dialog-capture",FileManager.default.fileExists(atPath:root.appendingPathComponent(name+".png").path))
                        librarySheet?.endSheet(removalSheet,returnCode:.alertSecondButtonReturn)
                    }
                    try await Task.sleep(for:.milliseconds(300))
                    check("extension-remove-cancel-keeps-record",host.records.contains{$0.id==id} && host.contexts[id] != nil)
                    host.chooseInstall(in:session)
                    for _ in 0..<50 {
                        if librarySheet?.attachedSheet is NSOpenPanel {break}
                        try await Task.sleep(for:.milliseconds(100))
                    }
                    let installPanel=librarySheet?.attachedSheet as? NSOpenPanel
                    check("extension-install-dialog-visible",installPanel != nil)
                    installPanel?.cancel(nil)
                    try await Task.sleep(for:.milliseconds(300))
                    check("extension-install-cancel-keeps-record",host.records.count==1 && host.records.first?.id==id)
                    let action=host.contexts[id]?.action(for:session.state.selectedTabID.map{session.bridge($0)})
                    await host.performFromLibrary(id,in:session)
                    for _ in 0..<100 {
                        if action?.popupPopover?.isShown == true {break}
                        try await Task.sleep(for:.milliseconds(50))
                    }
                    check("extension-action-from-library-shows-popup",session.window?.attachedSheet == nil && action?.popupPopover?.isShown == true)
                    let popupText=try? await action?.popupWebView?.evaluateJavaScript("document.body.innerText")
                    check("extension-popup-document-loaded",(popupText as? String)?.contains("Serein") == true)
                    if action?.popupPopover?.isShown == true {
                        let name="18-extension-action-popup"
                        try name.write(to:root.appendingPathComponent("capture-request"),atomically:true,encoding:.utf8)
                        for _ in 0..<100 {
                            if FileManager.default.fileExists(atPath:root.appendingPathComponent(name+".capture-finished").path){break}
                            try await Task.sleep(for:.milliseconds(100))
                        }
                        check("extension-popup-capture",FileManager.default.fileExists(atPath:root.appendingPathComponent(name+".png").path))
                    }
                    action?.popupPopover?.close()
                    try await Task.sleep(for:.milliseconds(300))
                }
                // Persist engine changes, including revocation, without depending on shutdown.
                guard let live=host.contexts[id] else{throw ExtensionValidationError.invalid("Missing reloaded context")}
                live.setPermissionStatus(.unknown,for:WKWebExtension.Permission(rawValue:"tabs"))
                try await Task.sleep(for:.milliseconds(100))
                let notificationRecords=try JSONDecoder().decode([InstalledExtension].self,from:Data(contentsOf:host.root.appendingPathComponent("extensions.json")))
                check("\(name)-permission-notification-persists",notificationRecords.first{$0.id==id}?.permissionState?.granted["tabs"] == nil && notificationRecords.first{$0.id==id}?.permissionState != nil)
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
                var expiredRecord=savedRecord
                expiredRecord.permissionState?.granted["tabs"]=Date(timeIntervalSince1970:0)
                let expiredData=try JSONEncoder().encode(expiredRecord)
                let expiredOnDisk=try JSONDecoder().decode(InstalledExtension.self,from:expiredData)
                try host.controller.unload(restored);host.contexts[id]=nil
                try await host.load(expiredOnDisk)
                check("\(name)-expired-grant-not-restored",host.contexts[id]?.hasPermission(WKWebExtension.Permission(rawValue:"tabs")) == false)

                await host.setEnabled(id,false)
                check("\(name)-disable-record",host.records.first{$0.id==id}?.enabled == false && host.contexts[id] == nil)
                session.current!.webView.reload();try await Task.sleep(for:.seconds(1))
                let disabled=try await session.current!.webView.evaluateJavaScript("document.documentElement.dataset.\(key) || null")
                check("\(name)-disable-stops-injection",disabled is NSNull)
                // Reinstallation may inject into an already loaded matching page.
                // Leave the probe document first so the reset counter has one producer.
                session.navigate("about:blank",ask:false)
                for _ in 0..<50 {
                    if session.current?.webView.url?.absoluteString=="about:blank",session.current?.isLoading==false {break}
                    try await Task.sleep(for:.milliseconds(100))
                }
                await host.remove(id)
                let remaining=await host.controller.dataRecords(ofTypes:WKWebExtensionController.allExtensionDataTypes.subtracting([.session]))
                check("\(name)-remove-disabled-data-errors",remaining.filter{$0.uniqueIdentifier==id.uuidString}.allSatisfy{$0.errors.isEmpty},"WebKit can retain an empty metadata record after removing storage.")
                check("\(name)-remove-package-and-record",!FileManager.default.fileExists(atPath:target.path) && !host.records.contains{$0.id==id},host.error ?? "")
                guard !FileManager.default.fileExists(atPath:target.path) else {throw ExtensionValidationError.invalid(host.error ?? "Removal left package installed") }
                // Metadata presence is not stored-value persistence. Reinstall with
                // the same identity and prove the old storage counter is gone.
                try host.prepare(source,at:target)
                try await host.load(granted);host.records.append(granted)
                session.navigate("http://127.0.0.1:8765/index.html?extension=\(name)-denied")
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
        do {
            let host = manager.extensions
            let source = Bundle.main.resourceURL!.appendingPathComponent("Fixtures/Packages/signed-fixture.crx")
            let installation = Task { await host.install(source, in: session) }
            for _ in 0..<100 {
                if session.dialogWindow?.attachedSheet != nil { break }
                try await Task.sleep(for: .milliseconds(100))
            }
            let owner = session.dialogWindow
            let consent = owner?.attachedSheet
            check("crx3-install-consent-visible", consent != nil)
            if let consent {
                let name = "22-crx3-install-consent"
                try name.write(to: root.appendingPathComponent("capture-request"), atomically: true, encoding: .utf8)
                for _ in 0..<100 {
                    if FileManager.default.fileExists(atPath: root.appendingPathComponent(name+".capture-finished").path) { break }
                    try await Task.sleep(for: .milliseconds(100))
                }
                check("crx3-install-consent-capture", FileManager.default.fileExists(atPath: root.appendingPathComponent(name+".png").path))
                owner?.endSheet(consent, returnCode: .alertFirstButtonReturn)
            }
            await installation.value
            let installed = host.records.first { $0.packageIdentity?.format == "CRX3" }
            check("crx3-installed-and-loaded", installed.map { host.contexts[$0.id] != nil } == true, host.error ?? "")
            let persisted = try JSONDecoder().decode([InstalledExtension].self, from: Data(contentsOf: host.root.appendingPathComponent("extensions.json")))
            check("crx3-identity-persists", installed != nil && persisted.first?.packageIdentity == installed?.packageIdentity)
            if let installed {
                let manifestData=try Data(contentsOf:ExtensionPackageLoader.manifest(installed.directory(in:host.root)))
                let ledger=installed.capabilityLedger
                try ledger?.validate(installed:manifestData)
                check("crx3-original-capabilities-persist",ledger != nil && persisted.first(where:{$0.id==installed.id})?.capabilityLedger==ledger && ledger?.requiredPermissions==["storage"])
                session.libraryPanel = .extensions
                try await Task.sleep(for:.milliseconds(300))
                try "extension-access-\(installed.id)".write(to:root.appendingPathComponent("extension-access-identifier"),atomically:true,encoding:.utf8)
                let previousSheet=session.dialogWindow?.attachedSheet
                try "extension-access".write(to:root.appendingPathComponent("keyboard-request"),atomically:true,encoding:.utf8)
                for _ in 0..<100 {
                    if FileManager.default.fileExists(atPath:root.appendingPathComponent("extension-access.keyboard-finished").path){break}
                    try await Task.sleep(for:.milliseconds(100))
                }
                for _ in 0..<50 {
                    if let sheet=session.dialogWindow?.attachedSheet,sheet !== previousSheet {break}
                    try await Task.sleep(for:.milliseconds(100))
                }
                let accessSheet=session.dialogWindow?.attachedSheet
                let opened=accessSheet != nil && accessSheet !== previousSheet && !FileManager.default.fileExists(atPath:root.appendingPathComponent("extension-access.keyboard-failed").path)
                check("crx3-native-requested-access-review",opened)
                let capture=opened ? "71-extension-requested-access" : "71-extension-requested-access-missing"
                try capture.write(to:root.appendingPathComponent("capture-request"),atomically:true,encoding:.utf8)
                for _ in 0..<100 {
                    if FileManager.default.fileExists(atPath:root.appendingPathComponent(capture+".capture-finished").path){break}
                    try await Task.sleep(for:.milliseconds(100))
                }
                check("crx3-requested-access-capture",opened && FileManager.default.fileExists(atPath:root.appendingPathComponent(capture+".png").path))
                if opened {
                    try "extension-access-close".write(to:root.appendingPathComponent("keyboard-request"),atomically:true,encoding:.utf8)
                    for _ in 0..<100 {
                        if session.dialogWindow?.attachedSheet==nil {break}
                        try await Task.sleep(for:.milliseconds(100))
                    }
                }
                check("crx3-requested-access-keyboard-close",opened && session.dialogWindow?.attachedSheet==nil)
                session.libraryPanel=nil
                session.navigate("http://127.0.0.1:8765/index.html?extension=crx-identity")
                var runtimeID: String?
                for _ in 0..<50 {
                    try await Task.sleep(for: .milliseconds(100))
                    runtimeID = try? await session.current?.webView.evaluateJavaScript("document.documentElement.dataset.sereinCRXIdentity") as? String
                    if runtimeID != nil { break }
                }
                check("crx3-developer-runtime-identity", runtimeID == installed.packageIdentity?.extensionID, runtimeID ?? "no identity")
                results += await ExtensionUpdateVerification.run(id: installed.id, host: host, session: session, root: root)
                await host.remove(installed.id)
                check("crx3-removal", !host.records.contains { $0.id == installed.id } && host.contexts[installed.id] == nil)
            }
        } catch { check("crx3-installation", false, error.localizedDescription) }
        return results
    }
}
