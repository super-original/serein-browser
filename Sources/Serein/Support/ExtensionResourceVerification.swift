import WebKit

@MainActor enum ExtensionResourceVerification {
    static func run(context:WKWebExtensionContext,session:BrowserSession,generation:Int) async -> [RuntimeVerification.Result] {
        var results:[RuntimeVerification.Result]=[]
        func check(_ name:String,_ passed:Bool){results.append(.init(name:"mv\(generation)-resource-"+name,passed:passed,detail:""))}
        let ordinary=URL(string:"http://127.0.0.1:8765/second.html?resource-check")!
        let id=session.newTab(url:ordinary.absoluteString,select:false),runtime=session.runtime(id)
        defer{session.close(id,ask:false)}
        func loaded(_ title:String) async -> Bool {
            for _ in 0..<50 {
                if runtime.webView.title==title,!runtime.webView.isLoading{return true}
                try? await Task.sleep(for:.milliseconds(100))
            }
            return false
        }
        let ready=await loaded("Second Field Note")
        check("source-loaded",ready)
        let target=context.baseURL.appendingPathComponent("public.html")
        let literal=String(data:try! JSONSerialization.data(withJSONObject:[target.absoluteString]),encoding:.utf8)!
        _=try? await runtime.webView.evaluateJavaScript("location.href="+literal+"[0]")
        let publicLoaded=await loaded("Public extension resource")
        check("declared-page-navigation",publicLoaded && runtime.webView.url==target)
        let priorBack=runtime.webView.backForwardList.backList.map(\.url)
        _=runtime.setZoom(1.2)
        runtime.suspend()
        check("suspension-keeps-zoom-without-waking",runtime.loadedWebView==nil && abs(session.bridge(id).zoomFactor(for:context)-1.2)<0.001 && runtime.loadedWebView==nil)
        let resumed=await loaded("Public extension resource")
        check("suspension-restores-extension-page",resumed && runtime.webView.url==target && abs(runtime.webView.pageZoom-1.2)<0.001)
        check("suspension-preserves-back-list",runtime.webView.backForwardList.backList.map(\.url)==priorBack)
        if generation==3 {
            let other=URL(string:"http://localhost:8765/second.html?resource-check")!
            runtime.load(other)
            check("other-origin-loaded",await loaded("Second Field Note"))
            _=try? await runtime.webView.evaluateJavaScript("location.href="+literal+"[0]")
            try? await Task.sleep(for:.milliseconds(500))
            check("unmatched-origin-denied",runtime.webView.url==other)
        }
        return results
    }
}
