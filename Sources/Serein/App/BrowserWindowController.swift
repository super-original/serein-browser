import AppKit
import SwiftUI

@MainActor final class BrowserWindowController: NSWindowController, NSWindowDelegate {
    let session: BrowserSession
    init(session: BrowserSession) {
        self.session=session
        let window=SereinWindow(contentRect:NSRect(x:10,y:60,width:1000,height:677),styleMask:[.titled,.closable,.miniaturizable,.resizable,.fullSizeContentView],backing:.buffered,defer:false)
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
        session.window=window;window.session=session;window.delegate=self
        window.contentView=NSHostingView(rootView:BrowserView(session:session))
        if let f=session.state.windowFrame,f.count==4,f.allSatisfy(\.isFinite),f[2]>=640,f[3]>=400 {
            let frame=NSRect(x:f[0],y:f[1],width:f[2],height:f[3])
            if NSScreen.screens.contains(where:{$0.visibleFrame.intersects(frame)}){window.setFrame(frame,display:true)}
        }
    }
    required init?(coder: NSCoder) {fatalError("Not supported")}
    func windowDidBecomeKey(_ notification: Notification) {
        if !session.state.isPrivate {session.extensions?.controller.didFocusWindow(session.extensionWindow)}
    }
    func windowDidMove(_ notification:Notification){rememberFrame()}
    func windowDidResize(_ notification:Notification){rememberFrame()}
    private func rememberFrame(){if let f=window?.frame{session.state.windowFrame=[f.origin.x,f.origin.y,f.width,f.height]}}
    func windowWillClose(_ notification: Notification) {session.manager?.windowClosed(self)}
    func windowShouldClose(_ sender: NSWindow) -> Bool {
        guard session.runtimes.values.contains(where:{$0.hasUserEdits}) else{return true}
        requestClose{_ in}
        return false
    }
    func requestClose(completion:@escaping (Bool)->Void) {
        guard session.manager?.windows.contains(where:{$0===self})==true else{completion(false);return}
        let close:() -> Void = { [weak self] in
            guard let self,self.session.manager?.windows.contains(where:{$0===self})==true else{completion(false);return}
            self.window?.close()
            completion(self.session.manager?.windows.contains(where:{$0===self})==false)
        }
        if session.runtimes.values.contains(where:{$0.hasUserEdits}) {
            let documents=session.closeConsentSnapshot
            session.confirm("Close this window?",detail:"One or more pages have edits. Unsaved changes may be lost.",yes:"Close") { [weak self] allow in
                guard allow,let self,self.session.closeConsentSnapshot==documents else{completion(false);return}
                // Consent is already validated. performClose may be suppressed
                // while AppKit is still dismissing the attached sheet.
                close()
            }
        } else {close()}
    }
}

@MainActor final class SereinWindow:NSWindow {
    weak var session:BrowserSession?
    override func sendEvent(_ event:NSEvent) {
        if ProcessInfo.processInfo.arguments.contains("--integration-test"),[NSEvent.EventType.leftMouseDown,.keyDown].contains(event.type),
           let session,session.state.activeGlance != nil || event.modifierFlags.contains(.option) {
            print("GLANCE_INPUT window=\(session.state.id) type=\(event.type.rawValue) modifiers=\(event.modifierFlags.rawValue) key=\(event.type == .keyDown ? Int(event.keyCode) : -1) selected=\(String(describing:session.state.selectedTabID)) point=\(event.locationInWindow)")
        }
        if let session,event.type == .keyDown,attachedSheet==nil {
            let modifiers=event.modifierFlags.intersection([.command,.option,.control,.shift])
            if event.keyCode==48,(modifiers == .control || modifiers == [.control,.shift]),
               let id=session.state.adjacentVisibleTab(modifiers.contains(.shift) ? -1 : 1) {
                session.select(id);return
            }
            if event.keyCode==53,modifiers.isEmpty,session.state.activeGlance != nil,
               !session.findVisible,!session.addressFocused {session.closeGlance();return}
        }
        super.sendEvent(event)
    }
    override func performKeyEquivalent(with event:NSEvent)->Bool {
        if super.performKeyEquivalent(with:event){return true}
        guard let session,!session.state.isPrivate else{return false}
        for context in session.extensions?.contexts.values ?? Dictionary<UUID,WebKit.WKWebExtensionContext>().values {
            if context.performCommand(for:event){return true}
        }
        return false
    }
}
import WebKit
