import AppKit
import SwiftUI

@MainActor final class BrowserWindowController: NSWindowController, NSWindowDelegate {
    let session: BrowserSession
    init(session: BrowserSession) {
        self.session=session
        let window=NSWindow(contentRect:NSRect(x:10,y:60,width:1000,height:677),styleMask:[.titled,.closable,.miniaturizable,.resizable,.fullSizeContentView],backing:.buffered,defer:false)
        window.title=session.state.isPrivate ? "Serein — Private Browsing" : "Serein"
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent=true
        window.titlebarSeparatorStyle = .none
        window.minSize=NSSize(width:640,height:400)
        window.autorecalculatesKeyViewLoop=true
        window.isReleasedWhenClosed=false
        window.tabbingMode = .disallowed
        window.collectionBehavior=[.fullScreenPrimary]
        super.init(window:window)
        session.window=window;window.delegate=self
        window.contentView=NSHostingView(rootView:BrowserView(session:session))
    }
    required init?(coder: NSCoder) {fatalError("Not supported")}
    func windowDidBecomeKey(_ notification: Notification) {
        if !session.state.isPrivate {session.extensions?.controller.didFocusWindow(session.extensionWindow)}
    }
    func windowWillClose(_ notification: Notification) {session.manager?.windowClosed(self)}
    func windowShouldClose(_ sender: NSWindow) -> Bool {
        if session.runtimes.values.contains(where:{$0.hasUserEdits}) {
            session.confirm("Close this window?",detail:"One or more pages have edits. Unsaved changes may be lost.",yes:"Close") { [weak self] allow in
                guard allow,let self else{return};for runtime in self.session.runtimes.values {runtime.hasUserEdits=false};self.window?.performClose(nil)
            };return false
        }
        return true
    }
}
