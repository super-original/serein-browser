import AppKit
import SereinCore

@MainActor enum SplitGridVerification {
    static func run(manager:BrowserManager,root:URL) async -> [RuntimeVerification.Result] {
        let previous=manager.active
        let session=manager.newWindow()
        defer{session.window?.close();previous?.window?.makeKeyAndOrderFront(nil)}
        var results:[RuntimeVerification.Result]=[]
        func check(_ name:String,_ passed:Bool,_ detail:String="") {results.append(.init(name:name,passed:passed,detail:detail))}
        func capture(_ name:String) async {
            try? name.write(to:root.appendingPathComponent("capture-request"),atomically:true,encoding:.utf8)
            for _ in 0..<100 {
                if FileManager.default.fileExists(atPath:root.appendingPathComponent(name+".capture-finished").path){break}
                try? await Task.sleep(for:.milliseconds(100))
            }
            check("capture-"+name,FileManager.default.fileExists(atPath:root.appendingPathComponent(name+".png").path))
        }
        let first=session.state.selectedTabID!
        session.navigate("http://127.0.0.1:8765/index.html?grid=0",ask:false)
        var ids=[first]
        for index in 1...3 {ids.append(session.newTab(url:"http://127.0.0.1:8765/"+(index%2==0 ? "index.html" : "second.html")+"?grid=\(index)",select:false))}
        for id in ids.prefix(3){_=session.setHighlighted(id,true)}
        session.splitHighlighted()
        try? await Task.sleep(for:.milliseconds(750))
        check("three-pane-composition",session.state.splitTabIDs==Array(ids.prefix(3)))
        await capture("29-three-pane-grid")
        _=session.setHighlighted(ids[3],true)
        session.splitHighlighted()
        for _ in 0..<60 {
            if ids.allSatisfy({session.runtimes[$0]?.loadedWebView?.title?.contains("Field Note")==true}){break}
            try? await Task.sleep(for:.milliseconds(100))
        }
        check("four-pane-independent-documents",ids.allSatisfy{session.runtimes[$0]?.loadedWebView?.url?.query=="grid=\(ids.firstIndex(of:$0)!)"})
        let frames=ids.compactMap{session.runtimes[$0]?.loadedWebView}.map{$0.convert($0.bounds,to:nil)}
        let grid=frames.count==4 && abs(frames[0].minX-frames[1].minX)<2 && abs(frames[2].minX-frames[3].minX)<2 && frames[0].maxX<frames[2].minX && frames[0].minY>frames[1].minY && frames[2].minY>frames[3].minY
        check("four-pane-native-grid-geometry",grid,frames.map{NSStringFromRect($0)}.joined(separator:"; "))
        var focus=true
        for id in ids {
            session.select(id);session.focusContent(ifSelected:id)
            focus = focus && session.window?.firstResponder === session.runtimes[id]?.loadedWebView
        }
        check("four-pane-focus-preserves-composition",focus && session.state.splitTabIDs==ids)
        check("all-visible-grid-panes-protected-from-unload",ids.allSatisfy{!session.canUnload($0)})
        await capture("30-four-pane-grid")
        session.close(ids[3],ask:false)
        check("closing-grid-pane-retains-other-three",session.state.splitTabIDs==Array(ids.prefix(3)))
        return results
    }
}
