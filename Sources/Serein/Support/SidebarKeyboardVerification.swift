import AppKit
import SereinCore

@MainActor enum SidebarKeyboardVerification {
    static func run(manager:BrowserManager,root:URL) async->[RuntimeVerification.Result] {
        var results:[RuntimeVerification.Result]=[]
        func check(_ name:String,_ pass:Bool,_ detail:String=""){results.append(.init(name:"sidebar-keyboard-"+name,passed:pass,detail:detail))}
        func wait(_ condition:@MainActor ()->Bool) async->Bool {
            for _ in 0..<100 {if condition(){return true};try? await Task.sleep(for:.milliseconds(100))};return false
        }
        func keyboard(_ name:String) async->Bool {
            let done=root.appendingPathComponent(name+".keyboard-finished"),failed=root.appendingPathComponent(name+".keyboard-failed")
            try? FileManager.default.removeItem(at:done);try? FileManager.default.removeItem(at:failed)
            try? name.write(to:root.appendingPathComponent("keyboard-request"),atomically:true,encoding:.utf8)
            let finished=await wait{FileManager.default.fileExists(atPath:done.path)}
            return finished && !FileManager.default.fileExists(atPath:failed.path)
        }
        let session=manager.newWindow()
        defer{session.window?.close()}
        let a=session.state.selectedTabID!,b=session.newTab(url:"http://127.0.0.1:8765/second.html?sidebar-key=b"),c=session.newTab(url:"http://127.0.0.1:8765/index.html?sidebar-key=c")
        session.select(a);session.navigate("http://127.0.0.1:8765/index.html?sidebar-key=a",ask:false)
        _=await wait{[a,b,c].allSatisfy{session.runtimes[$0]?.webView.isLoading==false && session.runtimes[$0]?.webView.url?.host=="127.0.0.1"}}
        let views=[a,b,c].compactMap{session.runtimes[$0]?.webView}
        session.window?.makeKeyAndOrderFront(nil)
        try? "tab-\(a)".write(to:root.appendingPathComponent("sidebar-focus-identifier"),atomically:true,encoding:.utf8)
        let focused=await keyboard("sidebar-focus")
        check("native-focus",focused && session.sidebarKeyboardFocus==a)
        let extend=await keyboard("sidebar-extend-down")
        check("extend-selection",extend && session.state.selectedTabID==b && session.tabSelection.ids==Set([a,b]) && session.sidebarKeyboardFocus==b)
        let extendAgain=await keyboard("sidebar-extend-down")
        check("extend-again",extendAgain && session.state.selectedTabID==c && session.tabSelection.ids==Set([a,b,c]) && session.sidebarKeyboardFocus==c)
        let contract=await keyboard("sidebar-contract-up")
        check("contract-to-anchor",contract && session.state.selectedTabID==b && session.tabSelection.ids==Set([a,b]) && session.sidebarKeyboardFocus==b)
        try? "75-sidebar-keyboard-selection".write(to:root.appendingPathComponent("capture-request"),atomically:true,encoding:.utf8)
        check("selection-captured",await wait{FileManager.default.fileExists(atPath:root.appendingPathComponent("75-sidebar-keyboard-selection.capture-finished").path)})
        let replace=await keyboard("sidebar-down")
        check("plain-arrow-replaces-selection",replace && session.state.selectedTabID==c && session.tabSelection.ids==Set([c]) && session.sidebarKeyboardFocus==c)
        let escape=await keyboard("sidebar-page-focus")
        let page=session.current?.webView
        let responder=session.window?.firstResponder as? NSView
        check("escape-restores-page-focus",escape && session.sidebarKeyboardFocus==nil && page != nil && (responder===page || responder?.isDescendant(of:page!)==true),"sidebarFocus=\(String(describing:session.sidebarKeyboardFocus)); responder=\(String(describing:responder.map{type(of:$0)})); pending=\(String(describing:session.contentFocusRequest))")
        check("live-views-preserved",views.count==3 && zip([a,b,c],views).allSatisfy{session.runtimes[$0.0]?.webView === $0.1})
        return results
    }
}
