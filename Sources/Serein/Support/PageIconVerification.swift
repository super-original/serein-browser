import AppKit
import WebKit

@MainActor enum PageIconVerification {
    static func run(manager:BrowserManager,root:URL) async->[RuntimeVerification.Result] {
        var results:[RuntimeVerification.Result]=[]
        func check(_ name:String,_ pass:Bool,_ detail:String=""){results.append(.init(name:"page-icon-"+name,passed:pass,detail:detail))}
        func wait(_ condition:@MainActor ()->Bool) async->Bool {
            for _ in 0..<100{if condition(){return true};try? await Task.sleep(for:.milliseconds(50))};return false
        }
        let previous=manager.active,session=manager.newWindow(),runtime=session.current!
        defer{session.window?.close();previous?.window?.makeKeyAndOrderFront(nil)}
        func load(_ query:String,in owner:BrowserSession) async->Bool {
            let runtime=owner.current!,url="http://127.0.0.1:8765/icon.html?"+query
            owner.navigate(url)
            return await wait{runtime.loadedWebView?.url?.absoluteString==url && !runtime.isLoading && runtime.pageIconDocumentID==runtime.documentID}
        }
        let loaded=await load("kind=normal",in:session)
        let image=runtime.pageIcon,bitmap=image?.tiffRepresentation.flatMap{NSBitmapImageRep(data:$0)}
        let corner=bitmap?.colorAt(x:0,y:0)?.usingColorSpace(.deviceRGB)
        check("original-fetch-raster-load",loaded && image?.size==NSSize(width:16,height:16) && (corner?.greenComponent ?? 0)>0.4 && (corner?.redComponent ?? 1)<0.2,"Page-world fetch is overridden after bootstrap; captured original fetch returns the original PNG")
        var svgRendered=false
        for format in ["jpeg","gif","tiff","webp","ico","svg"] {
            let ready=await load("kind="+format,in:session)
            let bitmap=runtime.pageIcon?.tiffRepresentation.flatMap{NSBitmapImageRep(data:$0)}
            let color=bitmap?.colorAt(x:0,y:0)?.usingColorSpace(.deviceRGB)
            if format=="svg" {svgRendered=ready && runtime.pageIcon != nil}
            check(format+"-raster-load",ready && runtime.pageIcon?.size==NSSize(width:16,height:16) && (color?.greenComponent ?? 0)>0.4 && (color?.redComponent ?? 1)<0.2)
        }
        for kind in ["cross","file","redirect","large","stream","wide","invalid","svgwide"] {
            let finished=await load("kind="+kind,in:session)
            check(kind+"-fallback",finished && runtime.pageIcon==nil && (kind != "svgwide" || svgRendered))
        }
        let rectangle=await load("kind=svgrect",in:session)
        check("svg-aspect-preserved",rectangle && runtime.pageIcon?.size==NSSize(width:16,height:8))
        let untrusted=await load("kind=svgunsafe",in:session)
        let svgDenied=await load("kind=svg&imgdeny=1",in:session)
        check("svg-image-csp-kept",svgRendered && svgDenied && runtime.pageIcon==nil)
        let external=try? await runtime.webView.callAsyncJavaScript("const r=await fetch('/icon-svg-audit');return (await r.json()).requests;",arguments:[:],in:nil,contentWorld:.world(name:"SereinIconAudit"))
        check("svg-no-script-or-external-fetch",svgRendered && untrusted && external as? Int==0)
        let policy=await load("kind=normal&deny=1",in:session)
        check("csp-connect-policy-kept",policy && runtime.pageIcon==nil)
        let removedPolicy=await load("kind=normal&deny=1&remove=1",in:session)
        check("removed-meta-policy-kept",removedPolicy && runtime.pageIcon==nil)
        let headerPolicy=await load("kind=normal&headerdeny=1",in:session)
        check("csp-header-policy-kept",headerPolicy && runtime.pageIcon==nil)
        let normalCookie=await load("kind=cookie&value=normal&cookie=normal",in:session)
        check("owning-store-cookie",normalCookie && runtime.pageIcon != nil)
        let privateSession=manager.newWindow(isPrivate:true)
        let excluded=await load("kind=cookie&value=normal",in:privateSession)
        check("private-cannot-use-normal-cookie",excluded && privateSession.current?.pageIcon==nil)
        let privateCookie=await load("kind=cookie&value=private&cookie=private",in:privateSession)
        check("private-own-cookie-loads",privateCookie && privateSession.current?.pageIcon != nil)
        privateSession.window?.close();session.window?.makeKeyAndOrderFront(nil)
        let normalUnchanged=await load("kind=cookie&value=normal",in:session)
        check("normal-cookie-not-replaced",normalUnchanged && runtime.pageIcon != nil)
        session.navigate("http://127.0.0.1:8765/icon.html?kind=slow")
        _=await wait{runtime.title=="Serein Icon Fixture" && !runtime.isLoading && runtime.pageIconDocumentID==nil}
        session.navigate("http://127.0.0.1:8765/index.html?icon=stale")
        _=await wait{runtime.title=="Field Notes" && !runtime.isLoading && runtime.pageIconDocumentID==runtime.documentID}
        try? await Task.sleep(for:.seconds(2))
        check("navigation-discards-old-image",runtime.title=="Field Notes" && runtime.pageIcon==nil)
        _=await load("kind=normal",in:session)
        let saved=runtime.pageIcon
        let other=session.newTab()
        runtime.suspend()
        check("unloaded-icon-kept-without-view",saved != nil && runtime.pageIcon === saved && runtime.loadedWebView==nil)
        session.select(runtime.id);session.close(other,ask:false)
        _=await wait{runtime.pageIcon != nil && runtime.pageIconDocumentID==runtime.documentID}
        _=try? await runtime.webView.evaluateJavaScript("document.cookie='sereinIcon=;path=/;Max-Age=0'")
        session.setKind(runtime.id,.essential)
        let pinned=session.newTab(url:"http://127.0.0.1:8765/icon.html?kind=normal&pinned=1")
        _=await wait{session.runtime(pinned).pageIcon != nil}
        session.setKind(pinned,.pinned)
        let regular=session.newTab(url:"http://127.0.0.1:8765/icon.html?kind=normal&regular=1")
        _=await wait{session.runtime(regular).pageIcon != nil}
        check("all-tab-kinds-have-icons",[runtime.id,pinned,regular].allSatisfy{session.runtimes[$0]?.pageIcon != nil})
        try? "59-tab-favicons".write(to:root.appendingPathComponent("capture-request"),atomically:true,encoding:.utf8)
        let captured=await wait{FileManager.default.fileExists(atPath:root.appendingPathComponent("59-tab-favicons.capture-finished").path)}
        check("sidebar-capture",captured && FileManager.default.fileExists(atPath:root.appendingPathComponent("59-tab-favicons.png").path))
        let previousAppearance=UserDefaults.standard.object(forKey:"appearance")
        defer {
            if let previousAppearance {UserDefaults.standard.set(previousAppearance,forKey:"appearance")}
            else {UserDefaults.standard.removeObject(forKey:"appearance")}
        }
        UserDefaults.standard.set("dark",forKey:"appearance")
        let darkApplied=await wait{session.window?.contentView?.effectiveAppearance.bestMatch(from:[.aqua,.darkAqua]) == .darkAqua}
        check("dark-appearance-applied",darkApplied)
        try? await Task.sleep(for:.milliseconds(500))
        try? "60-tab-favicons-dark".write(to:root.appendingPathComponent("capture-request"),atomically:true,encoding:.utf8)
        let darkCaptured=await wait{FileManager.default.fileExists(atPath:root.appendingPathComponent("60-tab-favicons-dark.capture-finished").path)}
        check("dark-sidebar-capture",darkApplied && darkCaptured && FileManager.default.fileExists(atPath:root.appendingPathComponent("60-tab-favicons-dark.png").path))
        return results
    }
}
