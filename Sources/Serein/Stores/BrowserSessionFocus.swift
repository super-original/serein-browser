import AppKit

extension BrowserSession {
    /// Called after address editing has ended. Do not take focus from a sheet,
    /// Find, another selected tab, or a detached web view.
    func focusContent(ifSelected id:UUID?) {
        guard let id,state.selectedTabID==id,!addressFocused,!findVisible,libraryPanel==nil,
              let window,window.attachedSheet==nil,let view=runtimes[id]?.loadedWebView,view.window===window else{return}
        window.makeFirstResponder(view)
    }
}
