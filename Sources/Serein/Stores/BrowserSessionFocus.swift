import AppKit

extension BrowserSession {
    /// Finish after AppKit updates the disappearing Find field's responder chain.
    /// Retain the request until focus is observed, but never override newer UI intent.
    func completeContentFocusRequest() {
        guard let id=contentFocusRequest else{return}
        guard state.selectedTabID==id,!addressFocused,!findVisible,libraryPanel==nil,
              let window,window.attachedSheet==nil else{contentFocusRequest=nil;return}
        guard let view=runtimes[id]?.loadedWebView,view.window===window else{return}
        if let responder=window.firstResponder as? NSView,responder===view || responder.isDescendant(of:view) {contentFocusRequest=nil;return}
        window.makeFirstResponder(view)
    }
    /// Called after address editing has ended. Do not take focus from a sheet,
    /// Find, another selected tab, or a detached web view.
    func focusContent(ifSelected id:UUID?) {
        guard let id,state.selectedTabID==id,!addressFocused,!findVisible,libraryPanel==nil,
              let window,window.attachedSheet==nil,let view=runtimes[id]?.loadedWebView,view.window===window else{return}
        window.makeFirstResponder(view)
    }
}
