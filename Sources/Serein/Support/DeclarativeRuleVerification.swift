import Foundation
import WebKit
import SereinCore

/// A background-free control distinguishes basic engine rules from real-package startup.
@MainActor enum DeclarativeRuleVerification {
    static func run(manager:BrowserManager) async->[RuntimeVerification.Result] {
        var results:[RuntimeVerification.Result]=[]
        let session=manager.newWindow(),privateSession=manager.newWindow(isPrivate:true)
        let host=manager.extensions,id=UUID()
        defer{session.window?.close();privateSession.window?.close()}
        func check(_ name:String,_ pass:Bool,_ detail:String="") {
            results.append(.init(name:"dnr-"+name,passed:pass,detail:detail))
            try? JSONEncoder().encode(results).write(to:manager.root.appendingPathComponent("dnr-partial-results.json"),options:.atomic)
        }
        func wait(_ condition:@MainActor ()->Bool) async {for _ in 0..<100{if condition(){return};try? await Task.sleep(for:.milliseconds(50))}}
        do {
            session.navigate("http://127.0.0.1:8765/index.html?dnr-page",ask:false)
            privateSession.navigate("http://127.0.0.1:8765/index.html?dnr-private",ask:false)
            let page=session.current!.webView,privatePage=privateSession.current!.webView
            await wait{page.title=="Field Notes" && !page.isLoading && privatePage.title=="Field Notes" && !privatePage.isLoading}
            func probe(_ view:WKWebView,_ tag:String) async->[String:Any]? {
                try? await view.callAsyncJavaScript("""
                const before=window.sereinBlockerLoads||0;
                return await new Promise(resolve=>{
                  const script=document.createElement('script');let done=false;
                  const finish=state=>{if(done)return;done=true;clearTimeout(timer);script.remove();resolve({state,executions:(window.sereinBlockerLoads||0)-before});};
                  const timer=setTimeout(()=>finish('timeout'),3000);
                  script.onload=()=>finish('loaded');script.onerror=()=>finish('error');
                  script.src='/serein-clean-probe.js?dnr='+tag+'&nonce='+nonce;document.head.append(script);
                });
                """,arguments:["tag":tag,"nonce":UUID().uuidString],in:nil,contentWorld:.page) as? [String:Any]
            }
            func loaded(_ value:[String:Any]?)->Bool{value?["state"] as? String=="loaded" && value?["executions"] as? Int==1}
            func blocked(_ tag:String) async->Bool {
                for _ in 0..<12 {
                    let value=await probe(page,tag)
                    if value?["state"] as? String=="error" && value?["executions"] as? Int==0{return true}
                    try? await Task.sleep(for:.milliseconds(100))
                }
                return false
            }
            check("baseline-loads",loaded(await probe(page,"static")))
            let source=Bundle.main.resourceURL!.appendingPathComponent("Fixtures/ExtensionDNR")
            try host.prepare(source,at:host.root.appendingPathComponent(id.uuidString))
            let record=InstalledExtension(id:id,name:"Declarative rules",version:"1.0",enabled:true,permissions:["declarativeNetRequest"],hosts:["http://127.0.0.1/*"])
            host.records.append(record);try await host.load(record)
            guard let options=host.contexts[id]?.optionsPageURL else{throw ExtensionValidationError.invalid("Missing declarative-rule options page")}
            let tab=session.newTab(url:options.absoluteString),runtime=session.runtime(tab)
            var optionsView:WKWebView?=runtime.webView
            await wait{optionsView?.title=="Declarative rule fixture" && optionsView?.isLoading==false}
            func api(_ operation:String) async->[String:Any]? {
                guard let view=optionsView else{return nil}
                return try? await view.callAsyncJavaScript("""
                try {
                  return await Promise.race([(async()=>{
                    const api=browser.declarativeNetRequest;
                    const rule=(id,tag)=>({id,priority:2,action:{type:'block'},condition:{urlFilter:'dnr='+tag,resourceTypes:['script']}});
                    if(operation==='disable-static') await api.updateEnabledRulesets({disableRulesetIds:['static']});
                    if(operation==='enable-static') await api.updateEnabledRulesets({enableRulesetIds:['static']});
                    if(operation==='add-dynamic') await api.updateDynamicRules({removeRuleIds:[101],addRules:[rule(101,'dynamic')]});
                    if(operation==='remove-dynamic') await api.updateDynamicRules({removeRuleIds:[101]});
                    if(operation==='add-session') await api.updateSessionRules({removeRuleIds:[201],addRules:[rule(201,'session')]});
                    if(operation==='remove-session') await api.updateSessionRules({removeRuleIds:[201]});
                    if(operation==='get-dynamic') return {ok:true,rules:await api.getDynamicRules()};
                    if(operation==='get-session') return {ok:true,rules:await api.getSessionRules()};
                    return {ok:true,enabled:await api.getEnabledRulesets()};
                  })(),new Promise(resolve=>setTimeout(()=>resolve({ok:false,error:'API timeout'}),4000))]);
                } catch(error){return {ok:false,error:String(error)};}
                """,arguments:["operation":operation],in:nil,contentWorld:.page) as? [String:Any]
            }
            let initial=await api("get-static")
            check("static-ruleset-enabled",initial?["enabled"] as? [String]==["static"],String(describing:initial))
            check("static-blocks-script",await blocked("static"))
            check("implicit-resource-types-block-script",await blocked("implicit"))
            check("unmatched-script-loads",loaded(await probe(page,"control")))
            check("private-store-excluded",loaded(await probe(privatePage,"static")) && privatePage.configuration.webExtensionController==nil)
            let disabled=await api("disable-static")
            check("static-disable-api",disabled?["ok"] as? Bool==true && disabled?["enabled"] as? [String]==[],String(describing:disabled))
            check("static-disable-restores-script",loaded(await probe(page,"static")))
            let enabled=await api("enable-static")
            check("static-enable-api",enabled?["ok"] as? Bool==true,String(describing:enabled))
            check("static-reenabled-blocks",await blocked("static"))
            let dynamic=await api("add-dynamic")
            check("dynamic-add-api",dynamic?["ok"] as? Bool==true,String(describing:dynamic))
            check("dynamic-blocks-script",await blocked("dynamic"))
            let sessionRules=await api("add-session"),queried=await api("get-session")
            check("session-add-and-query",sessionRules?["ok"] as? Bool==true && (queried?["rules"] as? [[String:Any]])?.compactMap{$0["id"] as? Int}==[201],String(describing:queried))
            check("session-blocks-script",await blocked("session"))
            let removedSession=await api("remove-session")
            let sessionRemovedLoad=await probe(page,"session")
            check("session-remove-restores-script",removedSession?["ok"] as? Bool==true && loaded(sessionRemovedLoad))
            optionsView=nil
            await host.setEnabled(id,false)
            let disabledStatic=await probe(page,"static"),disabledDynamic=await probe(page,"dynamic")
            check("extension-disable-removes-rules",host.contexts[id]==nil && loaded(disabledStatic) && loaded(disabledDynamic))
            await host.setEnabled(id,true)
            optionsView=runtime.webView
            await wait{optionsView?.title=="Declarative rule fixture" && optionsView?.isLoading==false}
            let savedRules=await api("get-dynamic")
            check("dynamic-rule-persists-context-recreation",(savedRules?["rules"] as? [[String:Any]])?.compactMap{$0["id"] as? Int}==[101],String(describing:savedRules))
            check("static-rule-restored",await blocked("static"))
            check("dynamic-rule-restored",await blocked("dynamic"))
            let removedDynamic=await api("remove-dynamic")
            let dynamicRemovedLoad=await probe(page,"dynamic")
            check("dynamic-remove-restores-script",removedDynamic?["ok"] as? Bool==true && loaded(dynamicRemovedLoad))
            optionsView=nil
            session.close(tab,ask:false)
            await host.remove(id)
            let removedStatic=await probe(page,"static"),removedResource=await probe(page,"dynamic")
            check("removal-restores-resources",!host.records.contains{$0.id==id} && loaded(removedStatic) && loaded(removedResource))
        } catch{check("setup",false,error.localizedDescription)}
        await host.remove(id)
        return results
    }
}
