import AppKit

@MainActor enum WindowConsentVerification {
    static func run(manager:BrowserManager) async -> [RuntimeVerification.Result] {
        let session=manager.newWindow()
        guard let window=session.window,let runtime=session.current else{return [.init(name:"window-consent-setup",passed:false,detail:"Missing window") ]}
        var results:[RuntimeVerification.Result]=[]
        func check(_ name:String,_ passed:Bool){results.append(.init(name:name,passed:passed,detail:"Native window close; in-process sheet response"))}
        runtime.hasUserEdits=true
        window.performClose(nil)
        let sheet=window.attachedSheet
        check("window-close-edits-prompt",sheet != nil)
        let added=session.newTab(select:false)
        if let sheet {window.endSheet(sheet,returnCode:.alertFirstButtonReturn)}
        try? await Task.sleep(for:.milliseconds(200))
        check("window-close-new-tab-invalidates-consent",manager.windows.contains{$0.session===session} && session.state.tabs.contains{$0.id==added} && runtime.hasUserEdits)
        window.performClose(nil)
        let secondSheet=window.attachedSheet
        check("window-close-requires-fresh-consent",secondSheet != nil)
        if let secondSheet {window.endSheet(secondSheet,returnCode:.alertSecondButtonReturn)}
        try? await Task.sleep(for:.milliseconds(200))
        check("window-close-cancel-keeps-edits",manager.windows.contains{$0.session===session} && runtime.hasUserEdits)
        window.performClose(nil)
        if let finalSheet=window.attachedSheet {window.endSheet(finalSheet,returnCode:.alertFirstButtonReturn)}
        try? await Task.sleep(for:.milliseconds(200))
        check("window-close-current-consent-removes-window",!manager.windows.contains{$0.session===session})
        // Retire only this controlled fixture window if a regression kept it open.
        if manager.windows.contains(where:{$0.session===session}) {window.close()}
        return results
    }
}
