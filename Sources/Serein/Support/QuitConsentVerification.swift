import AppKit

/// Separate application launch: unexpected termination cannot erase the main suite.
@MainActor enum QuitConsentVerification {
    static func run(manager:BrowserManager,root:URL) async {
        var results:[RuntimeVerification.Result]=[]
        guard let session=manager.active,let window=session.window,let runtime=session.current else{return}
        runtime.hasUserEdits=true
        func check(_ name:String,_ passed:Bool){results.append(.init(name:name,passed:passed,detail:"Actual NSApplication termination request and native sheet response"))}
        func sheet() async -> NSWindow? {
            for _ in 0..<40 {
                if let sheet=window.attachedSheet {return sheet}
                try? await Task.sleep(for:.milliseconds(50))
            }
            return nil
        }
        NSApp.terminate(nil)
        guard let cancelledSheet=await sheet() else{return}
        window.endSheet(cancelledSheet,returnCode:.alertSecondButtonReturn)
        try? await Task.sleep(for:.milliseconds(250))
        check("quit-cancel-keeps-app-and-edits",runtime.hasUserEdits && manager.windows.contains{$0.session===session})
        NSApp.terminate(nil)
        guard let staleSheet=await sheet() else{return}
        let added=session.newTab(select:false)
        window.endSheet(staleSheet,returnCode:.alertFirstButtonReturn)
        try? await Task.sleep(for:.milliseconds(250))
        check("quit-new-tab-invalidates-consent",runtime.hasUserEdits && session.state.tabs.contains{$0.id==added})
        NSApp.terminate(nil)
        guard let acceptedSheet=await sheet() else{return}
        check("quit-fresh-consent-required",window.attachedSheet===acceptedSheet)
        // The harness separately requires process exit and the final saved session.
        do {try JSONEncoder().encode(results).write(to:root.appendingPathComponent("results.json"),options:.atomic)} catch{return}
        window.endSheet(acceptedSheet,returnCode:.alertFirstButtonReturn)
    }
}
