import AppKit
import WebKit
import SereinCore

@MainActor enum SplitGroupVerification {
    static func run(manager:BrowserManager,root:URL) async -> [RuntimeVerification.Result] {
        let previous=manager.active,session=manager.newWindow()
        defer {session.window?.close();previous?.window?.makeKeyAndOrderFront(nil)}
        var results:[RuntimeVerification.Result]=[]
        func check(_ name:String,_ value:Bool,_ detail:String="") {results.append(.init(name:name,passed:value,detail:detail))}
        func settle() async {try? await Task.sleep(for:.milliseconds(400));session.window?.contentView?.layoutSubtreeIfNeeded()}
        func capture(_ name:String) async {
            try? name.write(to:root.appendingPathComponent("capture-request"),atomically:true,encoding:.utf8)
            for _ in 0..<100 {
                if FileManager.default.fileExists(atPath:root.appendingPathComponent(name+".capture-finished").path){break}
                try? await Task.sleep(for:.milliseconds(100))
            }
            check("capture-"+name,FileManager.default.fileExists(atPath:root.appendingPathComponent(name+".png").path))
        }
        let first=session.state.selectedTabID!
        session.navigate("http://127.0.0.1:8765/index.html?pair=0",ask:false)
        var ids=[first]
        for index in 1...3 {ids.append(session.newTab(url:"http://127.0.0.1:8765/"+(index%2==0 ? "index.html" : "second.html")+"?pair=\(index)",select:false))}
        session.state.setSplitTabs(Array(ids.prefix(2)));session.select(ids[0]);await settle()
        await capture("76-first-split-group")
        let firstViews=ids.prefix(2).compactMap{session.runtimes[$0]?.loadedWebView}
        for _ in 0..<50 {
            if firstViews.count==2 && firstViews.allSatisfy({$0.title?.contains("Field Note")==true && !$0.isLoading}) {break}
            try? await Task.sleep(for:.milliseconds(100))
        }
        var marked=firstViews.count==2
        for (index,view) in firstViews.enumerated() {
            let value=(try? await view.evaluateJavaScript("window.__sereinGroupDocument=\(index);location.search")) as? String
            marked = marked && value=="?pair=\(index)"
        }
        check("split-groups-first-documents-loaded",marked)
        session.state.setSplitFraction(0.37,at:0)
        session.select(ids[2]);session.state.setSplitTabs(Array(ids.suffix(2)));await settle()
        check("split-groups-independent-membership",session.state.splitGroups.count==2 && session.state.splitTabIDs==Array(ids.suffix(2)))
        check("split-groups-both-sidebar-rows-retained",session.state.regularSidebarRows.map(\.tabIDs)==[Array(ids.prefix(2)),Array(ids.suffix(2))])
        await capture("77-second-split-group")
        session.select(ids[0]);await settle()
        let current=ids.prefix(2).compactMap{session.runtimes[$0]?.loadedWebView}
        check("split-groups-return-retains-live-webviews",current.count==2 && current.map(ObjectIdentifier.init)==firstViews.map(ObjectIdentifier.init))
        var sameDocuments=current.count==2
        for (index,view) in current.enumerated() {
            let value=(try? await view.evaluateJavaScript("window.__sereinGroupDocument")) as? Int
            sameDocuments = sameDocuments && value==index
        }
        check("split-groups-return-retains-document-state",sameDocuments)
        let frames=current.map{$0.convert($0.bounds,to:nil)}
        check("split-groups-return-restores-native-divider",frames.count==2 && frames[0].width>100 && frames[1].width>100 && abs(Double(frames[0].width/(frames[0].width+frames[1].width))-0.37)<0.02,frames.map{NSStringFromRect($0)}.joined(separator:"; "))
        session.focusContent(ifSelected:ids[0])
        check("split-groups-return-content-focus",session.window?.firstResponder === current.first)
        await capture("78-return-first-split-group")
        do {
            var saved=try SavedSession.decode(SavedSession(windows:[session.state]).encoded()).windows[0];saved.id=UUID()
            let reopened=manager.newWindow(state:saved)
            defer {reopened.window?.close();session.window?.makeKeyAndOrderFront(nil)}
            reopened.select(ids[2]);try? await Task.sleep(for:.milliseconds(400))
            reopened.window?.contentView?.layoutSubtreeIfNeeded()
            let panes=ids.suffix(2).compactMap{reopened.runtimes[$0]?.loadedWebView}
            check("split-groups-session-restores-inactive-native-panes",reopened.state.splitGroups.count==2 && reopened.state.splitTabIDs==Array(ids.suffix(2)) && panes.count==2 && panes.allSatisfy{$0.window === reopened.window && $0.bounds.width>100 && $0.bounds.height>100})
        } catch {check("split-groups-session-restores-inactive-native-panes",false,error.localizedDescription)}
        session.state.clearSplit();session.select(ids[2]);await settle()
        check("split-groups-unsplit-preserves-other-group",session.state.splitTabIDs==Array(ids.suffix(2)) && session.state.splitGroups.count==1)
        return results
    }
}
