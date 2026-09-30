import AppKit
import WebKit

@MainActor enum ExtensionWindowCloseVerification {
    static func run(manager:BrowserManager,context:WKWebExtensionContext,name:String) async -> [RuntimeVerification.Result] {
        let previous=manager.active
        let session=manager.newWindow()
        defer{previous?.window?.makeKeyAndOrderFront(nil)}
        guard let window=session.window,let bridge=session.extensionWindow else{return [.init(name:name+"-window-close-setup",passed:false,detail:"Missing fixture window")]}
        var results:[RuntimeVerification.Result]=[]
        func check(_ suffix:String,_ passed:Bool){results.append(.init(name:name+"-window-close-"+suffix,passed:passed,detail:"Production WKWebExtensionWindow delegate; native sheet response. Not a JavaScript promise test."))}
        session.current?.hasUserEdits=true
        var completed=false;var error:Error?
        bridge.close(for:context){error=$0;completed=true}
        check("awaits-consent",!completed && window.attachedSheet != nil)
        if let sheet=window.attachedSheet{window.endSheet(sheet,returnCode:.alertSecondButtonReturn)}
        try? await Task.sleep(for:.milliseconds(250))
        check("cancel-reports-error",completed && error != nil && manager.windows.contains{$0.session===session})
        completed=false;error=nil
        bridge.close(for:context){error=$0;completed=true}
        let added=session.newTab(select:false)
        if let sheet=window.attachedSheet{window.endSheet(sheet,returnCode:.alertFirstButtonReturn)}
        try? await Task.sleep(for:.milliseconds(250))
        check("changed-tabs-report-error",completed && error != nil && session.state.tabs.contains{$0.id==added} && manager.windows.contains{$0.session===session})
        completed=false;error=nil
        bridge.close(for:context){error=$0;completed=true}
        if let sheet=window.attachedSheet{window.endSheet(sheet,returnCode:.alertFirstButtonReturn)}
        try? await Task.sleep(for:.milliseconds(250))
        check("success-after-removal",completed && error==nil && !manager.windows.contains{$0.session===session})
        if manager.windows.contains(where:{$0.session===session}){window.close()}
        return results
    }
}
