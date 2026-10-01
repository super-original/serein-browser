import Foundation
import WebKit
import CryptoKit
import SereinCore

/// Unmodified upstream uBO Lite package. A shipped EasyList rule is exercised on
/// loopback with positive controls; this is not universal blocker compatibility.
@MainActor enum RealContentBlockerVerification {
    static func run(firefoxOrigin:Bool=false) async->[RuntimeVerification.Result] {
        var results:[RuntimeVerification.Result]=[]
        func check(_ name:String,_ pass:Bool,_ detail:String=""){results.append(.init(name:"real-ubol-"+name,passed:pass,detail:detail))}
        func wait(_ condition:@MainActor ()->Bool) async {for _ in 0..<120{if condition(){return};try? await Task.sleep(for:.milliseconds(50))}}
        let args=ProcessInfo.processInfo.arguments
        guard let argument=args.firstIndex(of:"--real-extension-catalog"),args.indices.contains(argument+1) else{check("source",false,"No pinned catalog");return results}
        // Keep all third-party package/data outside the uploaded evidence root,
        // including when setup, unload or data removal fails.
        let temporary=FileManager.default.temporaryDirectory.appendingPathComponent("serein-real-blocker-"+UUID().uuidString)
        let manager=BrowserManager(root:temporary)
        let host=manager.extensions,id=UUID(),session=manager.newWindow(),privateSession=manager.newWindow(isPrivate:true)
        defer{
            session.window?.close();privateSession.window?.close()
            try? FileManager.default.removeItem(at:temporary)
        }
        do {
            let candidates=try JSONDecoder().decode([RealExtensionAudit.Candidate].self,from:Data(contentsOf:URL(fileURLWithPath:args[argument+1])))
            guard let candidate=candidates.first(where:{$0.name=="uBOLite_2026.930.1227.firefox.signed.xpi"}),let path=candidate.path else{throw ExtensionValidationError.invalid("Pinned uBO Lite package unavailable")}
            let source=URL(fileURLWithPath:path),expected="aaa62dfbaa453b75315419ad3274fc3521c2236eb2478d0ebf3d4e7a35f2b769"
            let bytes=try Data(contentsOf:source)
            guard bytes.count==9_634_550,SHA256.hash(data:bytes).map({String(format:"%02x",$0)}).joined()==expected else{throw ExtensionValidationError.invalid("Pinned uBO Lite source hash differs")}
            check("source-hash",true,"Official Firefox package 2026.930.1227; archive not redistributed")
            let tab=session.newTab(url:"http://127.0.0.1:8765/index.html?real-blocker"),view=session.runtime(tab).webView
            let privateTab=privateSession.newTab(url:"http://127.0.0.1:8765/index.html?private-real-blocker"),privateView=privateSession.runtime(privateTab).webView
            await wait{view.title=="Field Notes" && !view.isLoading && privateView.title=="Field Notes" && !privateView.isLoading}
            func probe(_ view:WKWebView,_ path:String) async->[String:Any]? {
                try? await view.callAsyncJavaScript("""
                const before=window.sereinBlockerLoads||0;
                return await new Promise(resolve=>{
                  const script=document.createElement('script');let done=false;
                  const finish=state=>{if(done)return;done=true;clearTimeout(timer);script.remove();resolve({state,executions:(window.sereinBlockerLoads||0)-before});};
                  const timer=setTimeout(()=>finish('timeout'),4000);
                  script.onload=()=>finish('loaded');script.onerror=()=>finish('error');
                  script.src=path+'?case='+nonce;document.head.append(script);
                });
                """,arguments:["path":path,"nonce":UUID().uuidString],in:nil,contentWorld:.page) as? [String:Any]
            }
            func loaded(_ value:[String:Any]?)->Bool{value?["state"] as? String=="loaded" && value?["executions"] as? Int==1}
            func blocked(_ value:[String:Any]?)->Bool{value?["state"] as? String=="error" && value?["executions"] as? Int==0}
            let blockingPath="/ads/!rotator/probe.js"
            check("baseline-resource-loads",loaded(await probe(view,blockingPath)))
            let target=host.root.appendingPathComponent(id.uuidString)
            try host.prepare(source,at:target)
            let ext=try await ExtensionPackageLoader.load(target)
            let record=InstalledExtension(id:id,name:"uBO Lite real-package scenario",version:"2026.930.1227",enabled:true,permissions:ext.requestedPermissions.map(\.rawValue),hosts:[],resourceBaseURL:firefoxOrigin ? ExtensionResourceOrigin.initialURL(sourceExtension:"xpi",id:id) : nil)
            host.records.append(record);try await host.load(record)
            guard let context=host.contexts[id] else{throw ExtensionValidationError.invalid("No live real-package context")}
            check("resource-origin",context.baseURL.scheme==(firefoxOrigin ? "moz-extension" : "webkit-extension") && context.uniqueIdentifier==id.uuidString,"Generated resource UUID; no publisher/native identity claim")
            let loopback=try WKWebExtension.MatchPattern(string:"http://127.0.0.1/*")
            context.setPermissionStatus(.grantedExplicitly,for:loopback)
            check("loaded-required-apis",true,"Named permissions validated by production loader; only loopback site access granted")
            let backgroundFailure=await ExtensionBackgroundProbe.failure(for:context)
            check("background-content-loads",backgroundFailure==nil,backgroundFailure ?? "Public background-load completion returned")
            let initialRuleStart=Date()
            var enabled:[String:Any]?
            while Date().timeIntervalSince(initialRuleStart)<30 {enabled=await probe(view,blockingPath);if blocked(enabled){break};try? await Task.sleep(for:.milliseconds(500))}
            check("shipped-rule-blocks-script",blocked(enabled),"elapsed=\(Date().timeIntervalSince(initialRuleStart)) result=\(String(describing:enabled))")
            check("unmatched-script-still-loads",loaded(await probe(view,"/serein-clean-probe.js")))
            check("private-window-excluded",loaded(await probe(privateView,blockingPath)) && privateView.configuration.webExtensionController==nil)
            if let options=context.optionsPageURL {
                let optionTab=session.newTab(url:options.absoluteString),optionView=session.runtime(optionTab).webView
                await wait{optionView.url==options && !optionView.isLoading}
                let reply=try? await optionView.callAsyncJavaScript("""
                try {
                  globalThis.__sereinOptionsReply=browser.runtime.sendMessage({what:'getOptionsPageData'}).then(value=>({status:'response',value:value??null}),error=>({status:'rejected',error:String(error)}));
                  return await Promise.race([
                    globalThis.__sereinOptionsReply,
                    new Promise(resolve=>setTimeout(()=>resolve({status:'timeout'}),10000))
                  ]);
                } catch(error){return {status:'rejected',error:String(error)};}
                """,arguments:[:],in:nil,contentWorld:.page) as? [String:Any]
                let data=reply?["value"] as? [String:Any]
                let readiness=reply?["status"] as? String=="timeout" ? await RealExtensionReadinessProbe.inspect(optionView) : "Not needed; original request completed."
                let late=reply?["status"] as? String=="timeout" ? await RealExtensionReadinessProbe.lateReply(optionView) : "Not needed."
                _=try? await optionView.evaluateJavaScript("delete globalThis.__sereinOptionsReply")
                check("original-options-background-roundtrip",(data?["enabledRulesets"] as? [String])?.contains("easylist")==true,"reply=\(String(describing:reply)) contextErrors=\(context.errors.map(\.localizedDescription)) readiness=\(readiness) late=\(late)")
                let rules=try? await optionView.callAsyncJavaScript("return await browser.declarativeNetRequest.getEnabledRulesets();",arguments:[:],in:nil,contentWorld:.page) as? [String]
                check("engine-enables-shipped-easylist",rules?.contains("easylist")==true,String(describing:rules))
                let errors=context.errors.map(\.localizedDescription)
                await wait{host.contextErrors[id] == errors}
                check("runtime-errors-reach-management",host.contextErrors[id] == errors,errors.joined(separator:"\n"))
                session.close(optionTab,ask:false)
            } else{check("original-options-background-roundtrip",false,"No original options page")}
            await host.setEnabled(id,false)
            let disabled=await probe(view,blockingPath)
            check("disable-restores-resource",host.contexts[id]==nil && loaded(disabled))
            await host.setEnabled(id,true)
            let restoredRuleStart=Date()
            var restored:[String:Any]?
            while Date().timeIntervalSince(restoredRuleStart)<30 {restored=await probe(view,blockingPath);if blocked(restored){break};try? await Task.sleep(for:.milliseconds(500))}
            check("reenable-restores-blocking",host.contexts[id] != nil && blocked(restored),"elapsed=\(Date().timeIntervalSince(restoredRuleStart)) result=\(String(describing:restored))")
        } catch {check("setup-or-load",false,error.localizedDescription)}
        await host.remove(id)
        return results
    }
}
