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
        let balanced=frames.count==4 && abs(frames[0].height-frames[1].height)<=1 && abs(frames[2].height-frames[3].height)<=1 && abs(frames[0].width-frames[2].width)<=1 && abs(frames[2].minX-frames[0].maxX-8)<=1
        check("four-pane-balanced-rows-and-reference-gap",balanced,frames.map{NSStringFromRect($0)}.joined(separator:"; "))
        var focus=true
        for id in ids {
            session.select(id);session.focusContent(ifSelected:id)
            focus = focus && session.window?.firstResponder === session.runtimes[id]?.loadedWebView
        }
        check("four-pane-focus-preserves-composition",focus && session.state.splitTabIDs==ids)
        check("all-visible-grid-panes-protected-from-unload",ids.allSatisfy{!session.canUnload($0)})
        await capture("30-four-pane-grid")
        if let window=session.window {
            let original=window.frame
            window.setFrame(NSRect(x:original.minX,y:original.minY,width:640,height:400),display:true)
            try? await Task.sleep(for:.milliseconds(300))
            let small=ids.compactMap{session.runtimes[$0]?.loadedWebView}.map{$0.convert($0.bounds,to:nil)}
            check("four-pane-minimum-window-size",small.count==4 && small.allSatisfy{$0.width>=119 && $0.height>=99 && $0.minX>=0 && $0.maxX<=640 && $0.minY>=0 && $0.maxY<=400},small.map{NSStringFromRect($0)}.joined(separator:"; "))
            await capture("31-four-pane-minimum-window")
            window.setFrame(original,display:true)
        }

        func grid(in view:NSView?)->BrowserGridSplitView? {
            guard let view else{return nil}
            if let split=view as? BrowserGridSplitView,split.paneIDs==ids{return split}
            for child in view.subviews {if let found=grid(in:child){return found}}
            return nil
        }
        func drag(_ split:BrowserGridSplitView,to fraction:Double) async -> Bool {
            guard let window=split.window,let screen=NSScreen.screens.first,let first=split.subviews.first else{return false}
            let length=(split.isVertical ? split.bounds.width : split.bounds.height)-split.dividerThickness
            let start=split.isVertical ? NSPoint(x:first.frame.maxX+4,y:split.bounds.midY) : NSPoint(x:split.bounds.midX,y:first.frame.maxY+4)
            let end=split.isVertical ? NSPoint(x:length*fraction+4,y:start.y) : NSPoint(x:start.x,y:length*fraction+4)
            let from=window.convertPoint(toScreen:split.convert(start,to:nil)),to=window.convertPoint(toScreen:split.convert(end,to:nil))
            let points="\(from.x) \(screen.frame.maxY-from.y) \(to.x) \(screen.frame.maxY-to.y)"
            try? points.write(to:root.appendingPathComponent("split-drag-points"),atomically:true,encoding:.utf8)
            let done=root.appendingPathComponent("split-divider-drag.keyboard-finished")
            try? FileManager.default.removeItem(at:done)
            try? "split-divider-drag".write(to:root.appendingPathComponent("keyboard-request"),atomically:true,encoding:.utf8)
            for _ in 0..<100 {if FileManager.default.fileExists(atPath:done.path){break};try? await Task.sleep(for:.milliseconds(100))}
            try? await Task.sleep(for:.milliseconds(250))
            return FileManager.default.fileExists(atPath:done.path)
        }
        if let split=grid(in:session.window?.contentView),let left=split.subviews.first as? BrowserGridSplitView {
            let horizontal=await drag(split,to:0.35),vertical=await drag(left,to:0.65)
            check("actual-divider-drag-persists-both-axes",horizontal && vertical && abs(session.state.splitFraction(at:0)-0.35)<0.02 && abs(session.state.splitFraction(at:1)-0.65)<0.02,"\(session.state.splitFractions ?? [])")
            let before=session.state.splitFractions
            if let window=session.window {
                let frame=window.frame;window.setFrame(NSRect(x:frame.minX,y:frame.minY,width:640,height:400),display:true)
                try? await Task.sleep(for:.milliseconds(200));window.setFrame(frame,display:true)
                try? await Task.sleep(for:.milliseconds(200))
            }
            check("window-resize-preserves-preferred-divider-fractions",session.state.splitFractions==before && abs(Double(split.subviews[0].frame.width/(split.bounds.width-8))-0.35)<0.02)
            await capture("50-resized-split-dividers")
            do {
                var restored=try SavedSession.decode(SavedSession(windows:[session.state]).encoded()).windows[0]
                restored.id=UUID()
                let reopened=manager.newWindow(state:restored)
                try? await Task.sleep(for:.milliseconds(500))
                let restoredGrid=grid(in:reopened.window?.contentView)
                let restoredLeft=restoredGrid?.subviews.first as? BrowserGridSplitView
                check("restored-native-dividers-use-saved-fractions",restoredGrid.map{abs(Double($0.subviews[0].frame.width/($0.bounds.width-8))-0.35)<0.02}==true && restoredLeft.map{abs(Double($0.subviews[0].frame.height/($0.bounds.height-8))-0.65)<0.02}==true)
                reopened.window?.close();session.window?.makeKeyAndOrderFront(nil)
            } catch {check("restored-native-dividers-use-saved-fractions",false,error.localizedDescription)}
        } else {check("actual-divider-drag-persists-both-axes",false,"Native split hierarchy unavailable")}
        session.close(ids[3],ask:false)
        check("closing-grid-pane-retains-other-three",session.state.splitTabIDs==Array(ids.prefix(3)))
        return results
    }
}
