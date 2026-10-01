import AppKit
import SereinCore

@MainActor enum WindowPlacementVerification {
    static func run(manager:BrowserManager,root:URL) async -> [RuntimeVerification.Result] {
        var results:[RuntimeVerification.Result]=[]
        func check(_ name:String,_ passed:Bool,_ detail:String=""){results.append(.init(name:"window-placement-"+name,passed:passed,detail:detail))}
        func wait(_ condition:@MainActor ()->Bool) async {
            for _ in 0..<200 {if condition(){return};try? await Task.sleep(for:.milliseconds(50))}
        }
        var state=BrowserWindowState();state.windowFrame=[9000,-4000,3000,2000]
        let session=manager.newWindow(state:state)
        guard let window=session.window,let controller=manager.windows.first(where:{$0.session === session}) else{return results}
        defer {window.close()}
        let visible=window.screen?.visibleFrame ?? .zero
        check("disconnected-display-reachable",visible.insetBy(dx:-1,dy:-1).contains(window.frame),"frame=\(window.frame) visible=\(visible)")
        let width=min(800,visible.width),height=min(500,visible.height)
        window.setFrame(NSRect(x:visible.minX+20,y:visible.maxY-height-20,width:width,height:height),display:true)
        let regular=session.state.windowFrame
        window.toggleFullScreen(nil)
        await wait{window.styleMask.contains(.fullScreen) && !controller.fullscreenTransition}
        let entered=window.styleMask.contains(.fullScreen) && !controller.fullscreenTransition
        check("native-fullscreen-keeps-normal-frame",entered && session.state.windowFrame==regular,"saved=\(String(describing:session.state.windowFrame)) regular=\(String(describing:regular))")
        manager.saveNow()
        do {
            let saved=try SavedSession.decode(Data(contentsOf:manager.root.appendingPathComponent("session.json")))
            check("persisted-normal-frame-in-fullscreen",entered && saved.windows.first(where:{$0.id==session.state.id})?.windowFrame==regular)
        } catch {check("persisted-normal-frame-in-fullscreen",false,error.localizedDescription)}
        if window.styleMask.contains(.fullScreen) {window.toggleFullScreen(nil)}
        await wait{!window.styleMask.contains(.fullScreen) && !controller.fullscreenTransition}
        check("native-fullscreen-exit-frame",entered && !window.styleMask.contains(.fullScreen) && session.state.windowFrame==regular,"saved=\(String(describing:session.state.windowFrame)) regular=\(String(describing:regular)) actual=\(window.frame) transition=\(controller.fullscreenTransition) fullscreen=\(window.styleMask.contains(.fullScreen))")
        let name="41-restored-window-placement"
        try? name.write(to:root.appendingPathComponent("capture-request"),atomically:true,encoding:.utf8)
        await wait{FileManager.default.fileExists(atPath:root.appendingPathComponent(name+".capture-finished").path)}
        return results
    }
}
