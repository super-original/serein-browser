import Foundation
import WebKit
import SereinCore

@MainActor enum ExtensionNetworkVerification {
    static func run(manager:BrowserManager) async->[RuntimeVerification.Result] {
        var results:[RuntimeVerification.Result]=[]
        let session=manager.newWindow(),privateSession=manager.newWindow(isPrivate:true)
        defer{session.window?.close();privateSession.window?.close()}
        func wait(_ condition:@MainActor ()->Bool) async {for _ in 0..<100 {if condition(){return};try? await Task.sleep(for:.milliseconds(50))}}
        for generation in [2,3] {
            let id=UUID(),host=manager.extensions,prefix="mv\(generation)-network-"
            let name="serein_network_"+id.uuidString.replacingOccurrences(of:"-",with:"_")
            func check(_ suffix:String,_ passed:Bool,_ detail:String="") {
                results.append(.init(name:prefix+suffix,passed:passed,detail:detail))
                print("NETWORK_VERIFY \(prefix+suffix): \(passed)");fflush(stdout)
                try? JSONEncoder().encode(results).write(to:manager.root.appendingPathComponent("network-partial-results.json"),options:.atomic)
            }
            do {
                let source=Bundle.main.resourceURL!.appendingPathComponent("Fixtures/ExtensionNetwork/mv\(generation)")
                try host.prepare(source,at:host.root.appendingPathComponent(id.uuidString))
                let record=InstalledExtension(id:id,name:prefix,version:"1.0",enabled:true,permissions:["cookies"],hosts:[])
                host.records.append(record);try await host.load(record)
                guard var context=host.contexts[id],let options=context.optionsPageURL,
                      let localhost=context.webExtension.requestedPermissionMatchPatterns.first(where:{$0.string=="http://localhost/*"}),
                      let loopback=context.webExtension.requestedPermissionMatchPatterns.first(where:{$0.string=="http://127.0.0.1/*"}) else{throw ExtensionValidationError.invalid("Missing network fixture context or host patterns")}
                context.setPermissionStatus(.deniedExplicitly,for:localhost)
                context.setPermissionStatus(.deniedExplicitly,for:loopback)
                let tab=session.newTab(url:options.absoluteString)
                var view=session.runtime(tab).webView
                await wait{view.title=="Network permission fixture" && !view.isLoading}
                check("options-ready",view.title=="Network permission fixture" && !view.isLoading)
                func request(_ operation:String,_ phase:String="") async->[String:Any]? {
                    try? await view.callAsyncJavaScript("""
                    return await Promise.race([
                      browser.runtime.sendMessage({kind:'network-fixture',operation,name,case:phase}),
                      new Promise(resolve=>setTimeout(()=>resolve({ok:false,timeout:true}),4000))
                    ]);
                    """,arguments:["operation":operation,"name":name,"phase":phase],in:nil,contentWorld:.page) as? [String:Any]
                }
                let denied=await request("fetch","denied")
                check("denied-host-cannot-read-response",denied?["ok"] as? Bool==false && denied?["error"] is String,String(describing:denied))
                context.setPermissionStatus(.grantedExplicitly,for:localhost)
                let allowed=await request("fetch","allowed"),body=allowed?["body"] as? [String:Any]
                check("granted-background-fetch",allowed?["ok"] as? Bool==true && allowed?["status"] as? Int==200 && body?["fixture"] as? String=="serein-network-v1" && body?["value"] as? String=="snow-雪",String(describing:allowed))
                check("expected-background-kind",allowed?["worker"] as? Bool==(generation==3))
                let redirect=await request("redirect","denied-redirect")
                check("redirect-rechecks-host-access",redirect?["ok"] as? Bool==false && redirect?["error"] is String,String(describing:redirect))
                context.setPermissionStatus(.grantedExplicitly,for:loopback)
                let redirectAllowed=await request("redirect","allowed-redirect")
                check("granted-redirect-loads",redirectAllowed?["ok"] as? Bool==true && (redirectAllowed?["url"] as? String)?.hasPrefix("http://127.0.0.1:8765/")==true,String(describing:redirectAllowed))
                context.setPermissionStatus(.deniedExplicitly,for:localhost)
                check("native-host-policy-records-revocation",context.permissionStatus(for:localhost) == .deniedExplicitly,"granted=\(context.grantedPermissionMatchPatterns.keys.map(\.string).sorted()) denied=\(context.deniedPermissionMatchPatterns.keys.map(\.string).sorted())")
                let revoked=await request("fetch","revoked")
                check("revoked-host-cannot-read-response",revoked?["ok"] as? Bool==false && revoked?["error"] is String,String(describing:revoked))
                var eventual=revoked
                for attempt in 0..<20 {
                    if eventual?["ok"] as? Bool==false && eventual?["error"] is String {break}
                    try? await Task.sleep(for:.milliseconds(100))
                    eventual=await request("fetch","revoked-settled-\(attempt)")
                }
                check("revoked-host-denied-after-propagation",eventual?["ok"] as? Bool==false && eventual?["error"] is String,"Immediate result remains separately asserted; bounded two-second propagation probe: \(String(describing:eventual))")
                context.setPermissionStatus(.grantedExplicitly,for:localhost)
                let set=await request("set"),cookie=set?["cookie"] as? [String:Any]
                check("cookie-set-properties",set?["ok"] as? Bool==true && cookie?["name"] as? String==name && cookie?["value"] as? String=="fixture-value" && cookie?["sameSite"] as? String=="lax" && cookie?["path"] as? String=="/",String(describing:set))
                let get=await request("get")
                check("cookie-read",(get?["cookie"] as? [String:Any])?["value"] as? String=="fixture-value",String(describing:get))
                var initialEvents:[[String:Any]]=[]
                for _ in 0..<20 {
                    initialEvents=(await request("events"))?["events"] as? [[String:Any]] ?? []
                    if !initialEvents.isEmpty {break}
                    try? await Task.sleep(for:.milliseconds(50))
                }
                check("cookie-insert-event-before-revocation",initialEvents.count==1 && initialEvents.first?["removed"] as? Bool==false && initialEvents.first?["cause"] as? String=="explicit",String(describing:initialEvents))
                let normal=await session.dataStore.httpCookieStore.allCookies(),isolated=await privateSession.dataStore.httpCookieStore.allCookies()
                check("cookie-uses-normal-browser-store",normal.contains{$0.name==name && $0.value=="fixture-value" && $0.domain=="localhost"})
                check("cookie-excludes-private-store",!isolated.contains{$0.name==name} && !privateSession.dataStore.isPersistent)
                context.setPermissionStatus(.deniedExplicitly,for:localhost)
                let deniedCookie=await request("get")
                check("cookie-host-revocation",deniedCookie?["ok"] as? Bool==false && deniedCookie?["error"] is String,String(describing:deniedCookie))
                check("cookie-revocation-does-not-disclose-value",deniedCookie?["error"] is String || deniedCookie?["cookie"] is NSNull,"Returning null without a permission error is separately recorded as a semantic mismatch")
                context.setPermissionStatus(.grantedExplicitly,for:localhost)
                context.setPermissionStatus(.deniedExplicitly,for:WKWebExtension.Permission(rawValue:"cookies"))
                let deniedAPI=await request("get")
                check("cookie-api-revocation",deniedAPI?["ok"] as? Bool==false && deniedAPI?["error"] is String,String(describing:deniedAPI))
                context.setPermissionStatus(.grantedExplicitly,for:WKWebExtension.Permission(rawValue:"cookies"))
                let removed=await request("remove")
                check("cookie-removal",removed?["ok"] as? Bool==true && (removed?["removed"] as? [String:Any])?["name"] as? String==name,String(describing:removed))
                var events:[[String:Any]]=[]
                for _ in 0..<20 {
                    events=(await request("events"))?["events"] as? [[String:Any]] ?? []
                    if events.contains(where:{$0["removed"] as? Bool==true}){break}
                    try? await Task.sleep(for:.milliseconds(50))
                }
                check("cookie-change-event-order",events.count==2 && events.first?["removed"] as? Bool==false && events.last?["removed"] as? Bool==true && events.allSatisfy{$0["cause"] as? String=="explicit"},String(describing:events))
                let eventDiagnostics=await request("events")
                check("cookie-change-events-have-required-payload",eventDiagnostics?["malformed"] as? Int==0,String(describing:eventDiagnostics))
                context.setPermissionStatus(.deniedExplicitly,for:localhost)
                await host.setEnabled(id,false)
                await host.setEnabled(id,true)
                guard let reloaded=host.contexts[id] else{throw ExtensionValidationError.invalid("Permission recreation did not reload")}
                context=reloaded;view=session.runtime(tab).webView
                await wait{view.title=="Network permission fixture" && !view.isLoading}
                let recreated=await request("fetch","revoked-recreated")
                check("recreated-context-enforces-revocation",recreated?["ok"] as? Bool==false && recreated?["error"] is String,"Public disable/re-enable with persisted denial: \(String(describing:recreated))")
                let policyURL=URL(string:"http://localhost:8765/index.html?site-denial-action")!
                let siteTab=session.newTab(url:policyURL.absoluteString),siteView=session.runtime(siteTab).webView
                await wait{siteView.url==policyURL && !siteView.isLoading}
                privateSession.navigate(policyURL.absoluteString,ask:false)
                let privateView=privateSession.current!.webView
                await wait{privateView.url==policyURL && !privateView.isLoading}
                let priorPolicy=context.permissionStatus(for:policyURL)
                check("private-site-policy-action-rejected",!host.setCurrentSite(id,in:privateSession,allow:true) && host.contexts[id] === context && context.permissionStatus(for:policyURL)==priorPolicy)
                let disabled=await host.denyCurrentSiteAndDisable(id,in:session)
                check("site-denial-action-disables-context",disabled && host.contexts[id]==nil && host.records.first{$0.id==id}?.enabled==false)
                let saved=try JSONDecoder().decode([InstalledExtension].self,from:Data(contentsOf:host.root.appendingPathComponent("extensions.json")))
                check("site-denial-action-persists-disabled-policy",saved.first{$0.id==id}?.enabled==false && !(saved.first{$0.id==id}?.permissionState?.deniedHosts.isEmpty ?? true))
                session.close(siteTab,ask:false)
                session.close(tab,ask:false)
            } catch{check("setup",false,error.localizedDescription)}
            // Remove only this fixture's cookie even if an earlier API assertion failed.
            for cookie in await session.dataStore.httpCookieStore.allCookies() where cookie.name==name {await session.dataStore.httpCookieStore.delete(cookie)}
            await host.remove(id)
        }
        return results
    }
}
