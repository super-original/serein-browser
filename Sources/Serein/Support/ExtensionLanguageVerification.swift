import AppKit
import WebKit

@MainActor enum ExtensionLanguageVerification {
    static func run(manager:BrowserManager,context:WKWebExtensionContext,name:String) async->[RuntimeVerification.Result] {
        let previous=manager.active,session=manager.newWindow()
        defer{session.window?.close();previous?.window?.makeKeyAndOrderFront(nil)}
        var results:[RuntimeVerification.Result]=[]
        func check(_ label:String,_ value:Bool,_ detail:String="") {results.append(.init(name:name+"-language-"+label,passed:value,detail:detail))}
        let resource=context.baseURL.appendingPathComponent("public.html")
        let observer=session.newTab(url:resource.absoluteString),view=session.runtime(observer).webView
        for _ in 0..<100 {if view.url==resource && !view.isLoading {break};try? await Task.sleep(for:.milliseconds(50))}
        let target=session.newTab(),runtime=session.runtime(target)
        func load(_ language:String) async -> String {
            let url="http://127.0.0.1:8765/language-\(language).html"
            runtime.load(URL(string:url)!)
            for _ in 0..<100 {if runtime.loadedWebView?.url?.absoluteString==url && !runtime.isLoading {break};try? await Task.sleep(for:.milliseconds(50))}
            return url
        }
        for language in ["en","fr","ja","empty"] {
            let url=await load(language)
            let reply=try? await view.callAsyncJavaScript("""
            const tab=(await browser.tabs.query({})).find(tab=>tab.url===url);
            if(!tab) return {error:'Owned tab missing'};
            return await Promise.race([
              browser.runtime.sendMessage({type:'language-probe',tabId:tab.id}),
              new Promise(resolve=>setTimeout(()=>resolve({error:'timeout'}),7000))
            ]);
            """,arguments:["url":url],in:nil,contentWorld:.page) as? [String:Any]
            check(language,reply?["language"] as? String==(language=="empty" ? "und" : language),String(describing:reply))
        }
        let bridge=session.bridge(target),snapshot=ExtensionPermissionState(context)
        let denied=await withCheckedContinuation {continuation in
            bridge.detectWebpageLocale(for:context){locale,error in continuation.resume(returning:locale==nil && error != nil)}
            context.grantedPermissions=[:];context.grantedPermissionMatchPatterns=[:]
        }
        check("revocation-during-request",denied)
        try? snapshot.apply(to:context)
        _=await load("en")
        let changed=await withCheckedContinuation {continuation in
            bridge.detectWebpageLocale(for:context){locale,error in continuation.resume(returning:locale==nil && error != nil)}
            runtime.load(URL(string:"http://127.0.0.1:8765/language-fr.html")!)
        }
        check("navigation-during-request",changed)
        _=await load("en")
        let stale=WKWebExtensionContext(for:context.webExtension)
        let staleDenied=await withCheckedContinuation {continuation in
            bridge.detectWebpageLocale(for:stale){locale,error in continuation.resume(returning:locale==nil && error != nil)}
        }
        check("unregistered-context-denied",staleDenied)
        let privateSession=manager.newWindow(isPrivate:true)
        let privateDenied=await withCheckedContinuation {continuation in
            privateSession.bridge(privateSession.state.selectedTabID!).detectWebpageLocale(for:context){locale,error in continuation.resume(returning:locale==nil && error != nil)}
        }
        privateSession.window?.close()
        check("private-tab-denied",privateDenied)
        return results
    }
}
