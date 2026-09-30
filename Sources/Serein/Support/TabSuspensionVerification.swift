import AppKit
import WebKit

@MainActor enum TabSuspensionVerification {
    static func run(manager:BrowserManager) async -> [RuntimeVerification.Result] {
        var results:[RuntimeVerification.Result]=[]
        func check(_ name:String,_ passed:Bool,_ detail:String=""){results.append(.init(name:"tab-suspension-"+name,passed:passed,detail:detail))}
        func wait(_ condition:@MainActor ()->Bool) async {
            for _ in 0..<150 {if condition(){return};try? await Task.sleep(for:.milliseconds(50))}
        }
        let session=manager.newWindow()
        defer {session.window?.close()}
        guard let id=session.state.selectedTabID else{return results}
        let runtime=session.runtime(id)
        for path in ["index.html?suspend=first","second.html?suspend=middle","index.html?suspend=last"] {
            let url=URL(string:"http://127.0.0.1:8765/"+path)!
            runtime.load(url)
            await wait{runtime.loadedWebView?.url==url && !runtime.isLoading}
        }
        runtime.goBack()
        await wait{runtime.loadedWebView?.url?.query=="suspend=middle" && !runtime.isLoading}
        _=runtime.setZoom(1.35)
        let expectedBack=runtime.webView.backForwardList.backList.map(\.url)
        let expectedCurrent=runtime.webView.url
        let expectedForward=runtime.webView.backForwardList.forwardList.map(\.url)
        check("setup-has-both-directions",!expectedBack.isEmpty && !expectedForward.isEmpty)
        session.newTab()
        for cycle in 1...2 {
            weak var retired=runtime.loadedWebView
            session.unload(id)
            let sheet=session.window?.attachedSheet
            if let sheet {session.window?.endSheet(sheet,returnCode:.alertFirstButtonReturn)}
            await wait{runtime.loadedWebView==nil}
            check("cycle-\(cycle)-unloads-after-consent",sheet != nil && runtime.loadedWebView==nil && session.runtimes[id] === runtime)
            check("cycle-\(cycle)-sleeping-zoom",abs(runtime.zoomFactor-1.35)<0.001 && runtime.loadedWebView==nil)
            await wait{retired==nil}
            check("cycle-\(cycle)-releases-old-view",retired==nil)
            session.select(id)
            await wait{runtime.loadedWebView?.url==expectedCurrent && !runtime.isLoading}
            let view=runtime.webView
            check("cycle-\(cycle)-history-and-position",view.url==expectedCurrent && view.backForwardList.backList.map(\.url)==expectedBack && view.backForwardList.forwardList.map(\.url)==expectedForward,"back=\(view.backForwardList.backList.map(\.url)) current=\(String(describing:view.url)) forward=\(view.backForwardList.forwardList.map(\.url))")
            check("cycle-\(cycle)-zoom",abs(view.pageZoom-1.35)<0.001)
            session.newTab()
        }
        session.select(id);runtime.goForward()
        await wait{runtime.loadedWebView?.url==expectedForward.first && !runtime.isLoading}
        check("forward-after-resume",runtime.loadedWebView?.url==expectedForward.first)
        return results
    }
}
