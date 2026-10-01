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
            func check(_ suffix:String,_ passed:Bool,_ detail:String=""){results.append(.init(name:prefix+suffix,passed:passed,detail:detail))}
            do {
                let source=Bundle.main.resourceURL!.appendingPathComponent("Fixtures/ExtensionNetwork/mv\(generation)")
                try host.prepare(source,at:host.root.appendingPathComponent(id.uuidString))
                let record=InstalledExtension(id:id,name:prefix,version:"1.0",enabled:true,permissions:["cookies"],hosts:[])
                host.records.append(record);try await host.load(record)
                guard let context=host.contexts[id],let options=context.optionsPageURL,
                      let localhost=context.webExtension.requestedPermissionMatchPatterns.first(where:{$0.string=="http://localhost/*"}),
                      let loopback=context.webExtension.requestedPermissionMatchPatterns.first(where:{$0.string=="http://127.0.0.1/*"}) else{throw ExtensionValidationError.invalid("Missing network fixture context or host patterns")}
                context.setPermissionStatus(.deniedExplicitly,for:localhost)
                context.setPermissionStatus(.deniedExplicitly,for:loopback)
                let tab=session.newTab(url:options.absoluteString),view=session.runtime(tab).webView
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
                let revoked=await request("fetch","revoked")
                check("revoked-host-cannot-read-response",revoked?["ok"] as? Bool==false && revoked?["error"] is String,String(describing:revoked))
                context.setPermissionStatus(.grantedExplicitly,for:localhost)
                let set=await request("set"),cookie=set?["cookie"] as? [String:Any]
                check("cookie-set-properties",set?["ok"] as? Bool==true && cookie?["name"] as? String==name && cookie?["value"] as? String=="fixture-value" && cookie?["sameSite"] as? String=="lax" && cookie?["path"] as? String=="/",String(describing:set))
                let get=await request("get")
                check("cookie-read",(get?["cookie"] as? [String:Any])?["value"] as? String=="fixture-value",String(describing:get))
                let normal=await session.dataStore.httpCookieStore.allCookies(),isolated=await privateSession.dataStore.httpCookieStore.allCookies()
                check("cookie-uses-normal-browser-store",normal.contains{$0.name==name && $0.value=="fixture-value" && $0.domain=="localhost"})
                check("cookie-excludes-private-store",!isolated.contains{$0.name==name} && !privateSession.dataStore.isPersistent)
                context.setPermissionStatus(.deniedExplicitly,for:localhost)
                let deniedCookie=await request("get")
                check("cookie-host-revocation",deniedCookie?["ok"] as? Bool==false && deniedCookie?["error"] is String,String(describing:deniedCookie))
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
                session.close(tab,ask:false)
            } catch{check("setup",false,error.localizedDescription)}
            // Remove only this fixture's cookie even if an earlier API assertion failed.
            for cookie in await session.dataStore.httpCookieStore.allCookies() where cookie.name==name {await session.dataStore.httpCookieStore.delete(cookie)}
            await host.remove(id)
        }
        return results
    }
}
