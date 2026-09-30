import AppKit
import WebKit
import SereinCore

@MainActor enum NativeHostVerification {
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
            try? name.write(to:root.appendingPathComponent("keyboard-request"),atomically:true,encoding:.utf8)
            await wait{FileManager.default.fileExists(atPath:done.path)}
            return FileManager.default.fileExists(atPath:done.path)
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
            func check(_ name:String,_ passed:Bool,_ detail:String=""){results.append(.init(name:prefix+name,passed:passed,detail:detail))}
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
                    host.nativeMessaging.chooseRegistration(for:record,in:session)
                    await wait{session.dialogWindow?.attachedSheet != nil}
                    let picked=await keyboard()
                    await wait{containsConsent(session.dialogWindow?.attachedSheet)}
                    let alert=session.dialogWindow?.attachedSheet
                    let consent=containsConsent(alert)
                    check(approve ? "registration-consent" : "registration-cancel-prompt",picked && consent && host.nativeMessaging.registrations(for:id).isEmpty)
                    if version==2,!approve {await capture("42-native-host-consent")}
                    if consent,let alert {session.dialogWindow?.endSheet(alert,returnCode:approve ? .alertFirstButtonReturn : .alertSecondButtonReturn)}
                    else {throw ExtensionValidationError.invalid("Native-host consent sheet did not appear.")}
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
                let response=try await call("return await browser.runtime.sendNativeMessage('org.serein.fixture',{text:'雪',items:[null,true,7]});") as? [String:Any]
                let echo=response?["echo"] as? [String:Any]
                check("one-shot-actual-process",echo?["text"] as? String=="雪" && (response?["pid"] as? Int ?? 0)>0 && response?["origin"] as? String=="chrome-extension://"+identity.extensionID+"/",String(describing:response))
                await wait{host.nativeMessaging.activeConnectionCount(for:id)==0}
                check("one-shot-child-cleanup",host.nativeMessaging.activeConnectionCount(for:id)==0)
                let unknown=try await call("try{await browser.runtime.sendNativeMessage('org.serein.unregistered',{});return false;}catch(error){return true;}") as? Bool
                check("unknown-host-denied",unknown==true)
                let port=try await call("""
                window.nativeDisconnected=false;
                return await new Promise((resolve,reject)=>{
                  const received=[],port=browser.runtime.connectNative('org.serein.fixture');window.nativeFixturePort=port;
                  const timer=setTimeout(()=>reject(new Error('native port timeout')),4000);
                  port.onDisconnect.addListener(()=>{window.nativeDisconnected=true;if(received.length<3){clearTimeout(timer);reject(new Error('early disconnect'));}});
                  port.onMessage.addListener(value=>{received.push(value);if(received.length===3){clearTimeout(timer);resolve(received);}});
                  for(let sequence=0;sequence<3;sequence++)port.postMessage({sequence});
                });
                """) as? [[String:Any]]
                check("persistent-port-order-and-origin",port?.compactMap{($0["echo"] as? [String:Any])?["sequence"] as? Int}==[0,1,2] && port?.allSatisfy{$0["origin"] as? String=="chrome-extension://"+identity.extensionID+"/"}==true,String(describing:port))
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
                session.close(tab,ask:false);await host.remove(id)
            } catch {
                check("scenario",false,error.localizedDescription)
                if let panel=session.dialogWindow?.attachedSheet {session.dialogWindow?.endSheet(panel,returnCode:.cancel)}
                session.libraryPanel=nil;await host.remove(id)
            }
        }
        return results
    }
}
