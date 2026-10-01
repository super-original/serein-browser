import AppKit
import Darwin
import WebKit
import SereinCore

@MainActor enum NativeHostVerification {
    /// Controlled setup only: production registration still requires user consent.
    static func prepareQuit(manager:BrowserManager,root:URL) async throws {
        let host=manager.extensions,id=UUID(),fixtures=Bundle.main.resourceURL!.appendingPathComponent("Fixtures/NativeHosts")
        guard let session=manager.active,let identity=try host.prepare(fixtures.appendingPathComponent("mv3.crx"),at:host.root.appendingPathComponent(id.uuidString)) else{throw NativeMessageTransportError.unavailable}
        let record=InstalledExtension(id:id,name:"Native quit fixture",version:"1.0",enabled:true,permissions:["nativeMessaging"],hosts:[],packageIdentity:identity,contextIdentifier:identity.extensionID)
        host.records.append(record);try await host.load(record)
        let manifest:[String:Any] = ["name":"org.serein.fixture","description":"Controlled quit fixture","path":fixtures.appendingPathComponent("NativeEcho").path,"type":"stdio","allowed_origins":["chrome-extension://"+identity.extensionID+"/"]]
        try host.nativeMessaging.register(NativeHostManifest(data:JSONSerialization.data(withJSONObject:manifest)),for:record)
        guard let options=host.contexts[id]?.optionsPageURL else{throw NativeMessageTransportError.unavailable}
        let tab=session.newTab(url:options.absoluteString),view=session.runtime(tab).webView
        for _ in 0..<160 {if view.title=="Native host fixture" && !view.isLoading{break};try await Task.sleep(for:.milliseconds(50))}
        let value=try await view.callAsyncJavaScript("""
        return await new Promise((resolve,reject)=>{
          const port=browser.runtime.connectNative('org.serein.fixture');window.nativeQuitPort=port;
          const timer=setTimeout(()=>reject(new Error('native quit setup timeout')),4000);
          port.onMessage.addListener(value=>{clearTimeout(timer);resolve(value.pid);});
          port.postMessage({quit:true});
        });
        """,arguments:[:],in:nil,contentWorld:.page)
        guard let pid=value as? Int,pid>0,host.nativeMessaging.activeConnectionCount(for:id)==1 else{throw NativeMessageTransportError.unavailable}
        try String(pid).write(to:root.appendingPathComponent("native-child-pid"),atomically:true,encoding:.utf8)
    }
    static func run(manager:BrowserManager,root:URL) async -> [RuntimeVerification.Result] {
        var results:[RuntimeVerification.Result]=[]
        let session=manager.newWindow(),host=manager.extensions
        defer {session.window?.close()}
        func wait(_ condition:@MainActor ()->Bool) async {
            for _ in 0..<160 {if condition(){return};try? await Task.sleep(for:.milliseconds(50))}
        }
        func capture(_ name:String) async {
            try? name.write(to:root.appendingPathComponent("capture-request"),atomically:true,encoding:.utf8)
            await wait{FileManager.default.fileExists(atPath:root.appendingPathComponent(name+".capture-finished").path)}
        }
        func keyboard() async -> Bool {
            let name="native-host-registration-file",done=root.appendingPathComponent(name+".keyboard-finished")
            try? FileManager.default.removeItem(at:done)
            let failed=root.appendingPathComponent(name+".keyboard-failed")
            try? FileManager.default.removeItem(at:failed)
            try? name.write(to:root.appendingPathComponent("keyboard-request"),atomically:true,encoding:.utf8)
            await wait{FileManager.default.fileExists(atPath:done.path)}
            return FileManager.default.fileExists(atPath:done.path) && !FileManager.default.fileExists(atPath:failed.path)
        }
        func containsConsent(_ window:NSWindow?)->Bool {
            func text(_ view:NSView)->Bool {
                if let field=view as? NSTextField,field.stringValue=="Allow this native application?"{return true}
                return view.subviews.contains(where:text)
            }
            return window?.contentView.map(text) ?? false
        }
        for version in [2,3] {
            let id=UUID(),prefix="mv\(version)-native-host-"
            func stage(_ name:String){try? (prefix+name).write(to:root.appendingPathComponent("native-host-stage.txt"),atomically:true,encoding:.utf8)}
            func check(_ name:String,_ passed:Bool,_ detail:String=""){
                results.append(.init(name:prefix+name,passed:passed,detail:detail))
                try? JSONEncoder().encode(results).write(to:root.appendingPathComponent("native-host-results.json"),options:.atomic)
                stage(name)
            }
            do {
                let fixtures=Bundle.main.resourceURL!.appendingPathComponent("Fixtures/NativeHosts")
                let destination=host.root.appendingPathComponent(id.uuidString)
                guard let identity=try host.prepare(fixtures.appendingPathComponent("mv\(version).crx"),at:destination) else{throw NativeMessageTransportError.unavailable}
                let record=InstalledExtension(id:id,name:prefix,version:"1.0",enabled:true,permissions:["nativeMessaging"],hosts:[],packageIdentity:identity,contextIdentifier:identity.extensionID)
                host.records.append(record);try await host.load(record)
                guard let context=host.contexts[id],let options=context.optionsPageURL else{throw NativeMessageTransportError.unavailable}
                let tab=session.newTab(url:options.absoluteString),view=session.runtime(tab).webView
                await wait{view.url==options && !view.isLoading && view.title=="Native host fixture"}
                func call(_ code:String) async throws -> Any? {try await view.callAsyncJavaScript(code,arguments:[:],in:nil,contentWorld:.page)}
                let denied=try await call("try{await browser.runtime.sendNativeMessage('org.serein.fixture',{text:'unregistered'});return false;}catch(error){return true;}") as? Bool
                check("unregistered-host-denied",denied==true && host.nativeMessaging.activeConnectionCount(for:id)==0)
                let manifest:[String:Any]=["name":"org.serein.fixture","description":"Controlled echo fixture","path":fixtures.appendingPathComponent("NativeEcho").path,"type":"stdio","allowed_origins":["chrome-extension://"+identity.extensionID+"/"]]
                let manifestFile=root.appendingPathComponent("native-host-manifest-mv\(version).json")
                try JSONSerialization.data(withJSONObject:manifest).write(to:manifestFile)
                try manifestFile.path.write(to:root.appendingPathComponent("native-host-manifest-path"),atomically:true,encoding:.utf8)
                session.libraryPanel = .extensions
                await wait{session.window?.attachedSheet != nil}
                for approve in [false,true] {
                    stage(approve ? "opening-allow-picker" : "opening-cancel-picker")
                    host.nativeMessaging.chooseRegistration(for:record,in:session)
                    await wait{session.dialogWindow?.attachedSheet != nil}
                    let picked=await keyboard()
                    stage("picker-input-returned")
                    await wait{containsConsent(session.dialogWindow?.attachedSheet)}
                    let pickerConsent=containsConsent(session.dialogWindow?.attachedSheet)
                    check(approve ? "picker-allow-input" : "picker-cancel-input",picked && pickerConsent,"Actual NSOpenPanel path entry and Open action")
                    if !pickerConsent {
                        await capture("native-host-picker-failure-mv\(version)")
                        if let panel=session.dialogWindow?.attachedSheet {session.dialogWindow?.endSheet(panel,returnCode:.cancel)}
                        await wait{session.dialogWindow?.attachedSheet==nil}
                        guard session.dialogWindow?.attachedSheet==nil else{throw ExtensionValidationError.invalid("The failed native picker did not close.")}
                        stage("review-controlled-fixture-after-picker-failure")
                        // Retain the failed picker result, then independently exercise
                        // the same production validation/consent using a known fixture.
                        host.nativeMessaging.reviewRegistration(manifestFile,for:record,in:session)
                        await wait{containsConsent(session.dialogWindow?.attachedSheet)}
                    }
                    let alert=session.dialogWindow?.attachedSheet
                    let consent=containsConsent(alert)
                    check(approve ? "registration-consent" : "registration-cancel-prompt",consent && host.nativeMessaging.registrations(for:id).isEmpty,pickerConsent ? "File-picker path" : "Controlled fixture URL; picker failure retained separately")
                    if version==2,!approve {await capture("42-native-host-consent")}
                    if consent,let alert {session.dialogWindow?.endSheet(alert,returnCode:approve ? .alertFirstButtonReturn : .alertSecondButtonReturn)}
                    else {throw ExtensionValidationError.invalid("Native-host consent sheet did not appear. \(host.error ?? "No host error")")}
                    await wait{session.dialogWindow?.attachedSheet==nil}
                    if approve {await wait{!host.nativeMessaging.registrations(for:id).isEmpty}}
                    else {check("cancel-keeps-host-unregistered",host.nativeMessaging.registrations(for:id).isEmpty)}
                }
                guard let registration=host.nativeMessaging.registrations(for:id).first else{throw NativeMessageTransportError.unavailable}
                let registry=host.root.appendingPathComponent("native-hosts.json")
                let persisted=try JSONDecoder().decode([NativeHostRegistration].self,from:Data(contentsOf:registry))
                let mode=(try FileManager.default.attributesOfItem(atPath:registry.path)[.posixPermissions] as? NSNumber)?.intValue
                check("registration-persisted-owner-only",persisted.contains{$0.id==registration.id && $0.publicKeySHA256==identity.publicKeySHA256} && mode==0o600)
                if version==3 {await capture("43-native-host-registered")}
                session.libraryPanel=nil;await wait{session.window?.attachedSheet==nil}
                let originalDeclarations=host.manifestAPIPermissions[id]
                host.manifestAPIPermissions[id]=["storage"]
                let undeclared=try? await call("try{await browser.runtime.sendNativeMessage('org.serein.fixture',{text:'undeclared'});return false;}catch(error){return true;}") as? Bool
                host.manifestAPIPermissions[id]=originalDeclarations
                check("original-declaration-required-despite-grant",undeclared==true && context.hasPermission(WKWebExtension.Permission(rawValue:"nativeMessaging")) && host.nativeMessaging.activeConnectionCount(for:id)==0)
                let response=try await call("return await browser.runtime.sendNativeMessage('org.serein.fixture',{text:'雪',items:[null,true,7]});") as? [String:Any]
                let echo=response?["echo"] as? [String:Any]
                check("one-shot-actual-process",echo?["text"] as? String=="雪" && (response?["pid"] as? Int ?? 0)>0 && response?["origin"] as? String=="chrome-extension://"+identity.extensionID+"/",String(describing:response))
                await wait{host.nativeMessaging.activeConnectionCount(for:id)==0}
                check("one-shot-child-cleanup",host.nativeMessaging.activeConnectionCount(for:id)==0)
                for operation in ["native-one-shot","native-background-port"] {
                    let background=try await call("return await browser.runtime.sendMessage({operation:'\(operation)'});") as? [String:Any]
                    let response=background?["response"] as? [String:Any],echo=response?["echo"] as? [String:Any]
                    let key=operation=="native-one-shot" ? "background" : "backgroundPort"
                    check(operation+"-execution-world",echo?[key] as? Bool==true && background?["worker"] as? Bool==(version==3) && (response?["pid"] as? Int ?? 0)>0,String(describing:background))
                    await wait{host.nativeMessaging.activeConnectionCount(for:id)==0}
                    check(operation+"-cleanup",host.nativeMessaging.activeConnectionCount(for:id)==0)
                }
                let unknown=try await call("try{await browser.runtime.sendNativeMessage('org.serein.unregistered',{});return false;}catch(error){return true;}") as? Bool
                check("unknown-host-denied",unknown==true)
                func openPort() async throws -> [[String:Any]]? {try await call("""
                window.nativeDisconnected=false;
                return await new Promise((resolve,reject)=>{
                  const received=[],port=browser.runtime.connectNative('org.serein.fixture');window.nativeFixturePort=port;
                  const timer=setTimeout(()=>reject(new Error('native port timeout')),4000);
                  port.onDisconnect.addListener(()=>{window.nativeDisconnected=true;if(received.length<3){clearTimeout(timer);reject(new Error('early disconnect'));}});
                  port.onMessage.addListener(value=>{received.push(value);if(received.length===3){clearTimeout(timer);resolve(received);}});
                  for(let sequence=0;sequence<3;sequence++)port.postMessage({sequence});
                });
                """) as? [[String:Any]]}
                let port=try await openPort()
                check("persistent-port-order-and-origin",port?.compactMap{($0["echo"] as? [String:Any])?["sequence"] as? Int}==[0,1,2] && port?.allSatisfy{$0["origin"] as? String=="chrome-extension://"+identity.extensionID+"/"}==true,String(describing:port))
                let permission=WKWebExtension.Permission(rawValue:"nativeMessaging")
                context.setPermissionStatus(.deniedExplicitly,for:permission)
                await wait{host.nativeMessaging.activeConnectionCount(for:id)==0}
                var permissionDisconnected=false
                for _ in 0..<100 {
                    permissionDisconnected=(try? await call("return window.nativeDisconnected===true;") as? Bool)==true
                    if permissionDisconnected{break};try? await Task.sleep(for:.milliseconds(50))
                }
                check("permission-revocation-stops-host",permissionDisconnected && host.nativeMessaging.activeConnectionCount(for:id)==0)
                let permissionDenied=try await call("try{await browser.runtime.sendNativeMessage('org.serein.fixture',{});return false;}catch(error){return true;}") as? Bool
                check("permission-revocation-denies-new-call",permissionDenied==true)
                context.setPermissionStatus(.grantedExplicitly,for:permission)
                let reopened=try await openPort()
                check("permission-regrant-reconnects",reopened?.count==3 && host.nativeMessaging.activeConnectionCount(for:id)==1)
                host.nativeMessaging.revoke(registration.id)
                var disconnected=false
                for _ in 0..<100 {
                    disconnected=(try? await call("return window.nativeDisconnected===true;") as? Bool)==true
                    if disconnected && host.nativeMessaging.activeConnectionCount(for:id)==0 {break}
                    try? await Task.sleep(for:.milliseconds(50))
                }
                check("revoke-disconnects-and-reaps-child",disconnected && host.nativeMessaging.activeConnectionCount(for:id)==0 && host.nativeMessaging.registrations(for:id).isEmpty)
                let revoked=try await call("try{await browser.runtime.sendNativeMessage('org.serein.fixture',{});return false;}catch(error){return true;}") as? Bool
                check("revoked-host-denied",revoked==true)
                // Controlled re-registration reuses the manifest already approved above.
                try host.nativeMessaging.register(NativeHostManifest(data:JSONSerialization.data(withJSONObject:manifest)),for:record)
                let disablePort=try await openPort(),child=disablePort?.first?["pid"] as? Int
                await host.setEnabled(id,false)
                await wait{host.nativeMessaging.activeConnectionCount(for:id)==0}
                let gone=child.map{kill(pid_t($0),0) == -1 && errno==ESRCH} ?? false
                check("disable-reaps-native-child",child != nil && gone && host.contexts[id]==nil && host.nativeMessaging.activeConnectionCount(for:id)==0)
                session.close(tab,ask:false);await host.remove(id)
                check("remove-clears-registration",host.nativeMessaging.registrations(for:id).isEmpty)
            } catch {
                check("scenario",false,error.localizedDescription)
                if let panel=session.dialogWindow?.attachedSheet {session.dialogWindow?.endSheet(panel,returnCode:.cancel)}
                session.libraryPanel=nil;await host.remove(id)
            }
        }
        return results
    }
}
