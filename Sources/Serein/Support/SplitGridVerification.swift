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

        func findGrid(in view:NSView?)->BrowserGridSplitView? {
            guard let view else{return nil}
            if let split=view as? BrowserGridSplitView,split.paneIDs==ids{return split}
            for child in view.subviews {if let found=findGrid(in:child){return found}}
            return nil
        }
        func drag(_ split:BrowserGridSplitView,to fraction:Double,name:String) async -> Bool {
            // Let the prior window resize commit before converting pointer coordinates.
            try? await Task.sleep(for:.milliseconds(250))
            split.window?.contentView?.layoutSubtreeIfNeeded()
            guard let window=split.window,let screen=NSScreen.screens.first,let first=split.subviews.first else{return false}
            let length=(split.isVertical ? split.bounds.width : split.bounds.height)-split.dividerThickness*CGFloat(split.subviews.count-1)
            let start=split.isVertical ? NSPoint(x:first.frame.maxX+4,y:split.bounds.midY) : NSPoint(x:split.bounds.midX,y:first.frame.maxY+4)
            let end=split.isVertical ? NSPoint(x:length*fraction+4,y:start.y) : NSPoint(x:start.x,y:length*fraction+4)
            let from=window.convertPoint(toScreen:split.convert(start,to:nil)),to=window.convertPoint(toScreen:split.convert(end,to:nil))
            let points="\(from.x) \(screen.frame.maxY-from.y) \(to.x) \(screen.frame.maxY-to.y)"
            try? ("bounds=\(NSStringFromRect(split.bounds)) first=\(NSStringFromRect(first.frame)) points=\(points)\n").write(to:root.appendingPathComponent("split-"+name+"-geometry.txt"),atomically:true,encoding:.utf8)
            try? (points+"\n").write(to:root.appendingPathComponent("split-drag-points"),atomically:true,encoding:.utf8)
            let done=root.appendingPathComponent("split-divider-drag.keyboard-finished")
            let failed=root.appendingPathComponent("split-divider-drag.keyboard-failed")
            try? FileManager.default.removeItem(at:done);try? FileManager.default.removeItem(at:failed)
            try? "split-divider-drag".write(to:root.appendingPathComponent("keyboard-request"),atomically:true,encoding:.utf8)
            for _ in 0..<100 {if FileManager.default.fileExists(atPath:done.path){break};try? await Task.sleep(for:.milliseconds(100))}
            try? await Task.sleep(for:.milliseconds(250))
            return FileManager.default.fileExists(atPath:done.path) && !FileManager.default.fileExists(atPath:failed.path)
        }
        if let split=findGrid(in:session.window?.contentView),let left=split.subviews.first as? BrowserGridSplitView {
            let horizontal=await drag(split,to:0.35,name:"columns"),vertical=await drag(left,to:0.65,name:"left-rows")
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
                let restoredGrid=findGrid(in:reopened.window?.contentView)
                let restoredLeft=restoredGrid?.subviews.first as? BrowserGridSplitView
                let restoredRootRatio=restoredGrid.map{Double($0.subviews[0].frame.width/($0.bounds.width-8))}
                let restoredLeftRatio=restoredLeft.map{Double($0.subviews[0].frame.height/($0.bounds.height-8))}
                let rootMatches=restoredRootRatio.map{abs($0-0.35)<0.02} ?? false
                let leftMatches=restoredLeftRatio.map{abs($0-0.65)<0.02} ?? false
                check("restored-native-dividers-use-saved-fractions",rootMatches && leftMatches,"root=\(String(describing:restoredRootRatio)) left=\(String(describing:restoredLeftRatio))")
                reopened.window?.close();session.window?.makeKeyAndOrderFront(nil)
            } catch {check("restored-native-dividers-use-saved-fractions",false,error.localizedDescription)}
        } else {check("actual-divider-drag-persists-both-axes",false,"Native split hierarchy unavailable")}
        let views=ids.compactMap{session.runtimes[$0]?.loadedWebView}.map(ObjectIdentifier.init)
        func layoutKey(_ name:String) async -> Bool {
            let done=root.appendingPathComponent(name+".keyboard-finished"),failed=root.appendingPathComponent(name+".keyboard-failed")
            try? FileManager.default.removeItem(at:done);try? FileManager.default.removeItem(at:failed)
            try? name.write(to:root.appendingPathComponent("keyboard-request"),atomically:true,encoding:.utf8)
            for _ in 0..<100 {if FileManager.default.fileExists(atPath:done.path){break};try? await Task.sleep(for:.milliseconds(100))}
            try? await Task.sleep(for:.milliseconds(350))
            session.window?.contentView?.layoutSubtreeIfNeeded()
            return FileManager.default.fileExists(atPath:done.path) && !FileManager.default.fileExists(atPath:failed.path)
        }
        for layout in [SplitLayout.rows,.columns,.grid] {
            let key=await layoutKey("split-"+layout.rawValue)
            let frames=ids.compactMap{session.runtimes[$0]?.loadedWebView}.map{$0.convert($0.bounds,to:nil)}
            let ordered:Bool
            if frames.count != 4 {ordered=false}
            else if layout == .rows {ordered=zip(frames,frames.dropFirst()).allSatisfy{$0.minY>$1.maxY && abs($0.minX-$1.minX)<2 && abs($0.width-$1.width)<2 && abs($0.height-$1.height)<2}}
            else if layout == .columns {ordered=zip(frames,frames.dropFirst()).allSatisfy{$0.maxX<$1.minX && abs($0.minY-$1.minY)<2 && abs($0.height-$1.height)<2 && abs($0.width-$1.width)<2}}
            else {ordered=abs(frames[0].minX-frames[1].minX)<2 && frames[0].maxX<frames[2].minX && frames[0].minY>frames[1].minY}
            check("split-"+layout.rawValue+"-keyboard-and-native-geometry",key && session.state.resolvedSplitLayout==layout && session.state.splitTabIDs==ids && ordered,frames.map{NSStringFromRect($0)}.joined(separator:"; "))
            check("split-"+layout.rawValue+"-retains-live-documents",ids.compactMap{session.runtimes[$0]?.loadedWebView}.map(ObjectIdentifier.init)==views)
            check("split-"+layout.rawValue+"-restores-content-focus",session.window?.firstResponder === session.current?.loadedWebView)
            await capture(layout == .rows ? "63-split-rows" : layout == .columns ? "64-split-columns" : "65-split-grid-restored")
            if layout == .rows,let split=findGrid(in:session.window?.contentView) {
                let moved=await drag(split,to:0.3,name:"rows")
                check("split-rows-native-divider-persists",moved && abs(session.state.splitFraction(at:0)-0.3)<0.02)
                do {
                    var saved=try SavedSession.decode(SavedSession(windows:[session.state]).encoded()).windows[0];saved.id=UUID()
                    let restored=manager.newWindow(state:saved)
                    try? await Task.sleep(for:.milliseconds(400));restored.window?.contentView?.layoutSubtreeIfNeeded()
                    let native=findGrid(in:restored.window?.contentView)
                    let fraction=native.flatMap {view->Double? in
                        guard view.subviews.count==4 else{return nil}
                        return Double(view.subviews[0].frame.height/(view.bounds.height-24))
                    }
                    check("split-rows-restored-native-boundaries",native?.isVertical==false && fraction.map{abs($0-0.3)<0.02}==true)
                    restored.window?.close();session.window?.makeKeyAndOrderFront(nil)
                } catch {check("split-rows-restored-native-boundaries",false,error.localizedDescription)}
            }
        }
        let unsplit=await layoutKey("split-unsplit")
        check("split-unsplit-keyboard",unsplit && session.state.splitTabIDs.isEmpty)
        let pair=await layoutKey("split-columns")
        check("split-layout-keyboard-creates-next-pair",pair && session.state.splitTabIDs.count==2 && session.state.resolvedSplitLayout == .columns)
        _=session.state.setSplitTabs(ids);session.state.setSplitLayout(.grid)
        session.close(ids[3],ask:false)
        check("closing-grid-pane-retains-other-three",session.state.splitTabIDs==Array(ids.prefix(3)))
        return results
    }
}
