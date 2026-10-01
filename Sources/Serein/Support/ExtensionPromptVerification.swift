import AppKit
import WebKit
import SereinCore

/// Actual native sheets and production delegate callbacks. These calls test the
/// host's consent boundary, not JavaScript optional-permission event semantics.
@MainActor enum ExtensionPromptVerification {
    private final class Reply {var count:Int?}
    static func run(manager:BrowserManager) async->[RuntimeVerification.Result] {
        var results:[RuntimeVerification.Result]=[]
        let session=manager.newWindow(),privateSession=manager.newWindow(isPrivate:true)
        defer{session.window?.close();privateSession.window?.close()}
        let host=manager.extensions,id=UUID()
        func check(_ name:String,_ pass:Bool,_ detail:String=""){results.append(.init(name:"extension-consent-"+name,passed:pass,detail:detail))}
        func wait(_ condition:@MainActor ()->Bool) async {for _ in 0..<100{if condition(){return};try? await Task.sleep(for:.milliseconds(50))}}
        do {
            let source=Bundle.main.resourceURL!.appendingPathComponent("Fixtures/ExtensionPermissionPrompt")
            try host.prepare(source,at:host.root.appendingPathComponent(id.uuidString))
            let record=InstalledExtension(id:id,name:"Permission prompt fixture",version:"1.0",enabled:true,permissions:[],hosts:[])
            host.records.append(record);try await host.load(record)
            guard let window=session.window,let tabID=session.state.selectedTabID else{throw ExtensionValidationError.invalid("Missing normal fixture window")}
            window.makeKeyAndOrderFront(nil)
            let tab=session.bridge(tabID)
            let pattern=try WKWebExtension.MatchPattern(string:"http://localhost/*")
            func request(_ kind:Int,_ context:WKWebExtensionContext,_ tab:any WKWebExtensionTab)->Reply {
                let reply=Reply()
                switch kind {
                case 0:host.webExtensionController(host.controller,promptForPermissions:[WKWebExtension.Permission(rawValue:"storage")],in:tab,for:context){permissions,_ in reply.count=permissions.count}
                case 1:host.webExtensionController(host.controller,promptForPermissionMatchPatterns:[pattern],in:tab,for:context){permissions,_ in reply.count=permissions.count}
                default:host.webExtensionController(host.controller,promptForPermissionToAccess:[URL(string:"http://localhost:8765/")!],in:tab,for:context){permissions,_ in reply.count=permissions.count}
                }
                return reply
            }
            for kind in 0..<3 {
                if host.contexts[id]==nil {await host.setEnabled(id,true)}
                guard let context=host.contexts[id] else{throw ExtensionValidationError.invalid("Context did not reload")}
                let allowed=request(kind,context,tab)
                await wait{window.attachedSheet != nil || allowed.count != nil}
                let sheet=window.attachedSheet
                if let sheet{window.endSheet(sheet,returnCode:.alertFirstButtonReturn)}
                await wait{allowed.count != nil && window.attachedSheet==nil}
                check("kind-\(kind)-live-context-grants",sheet != nil && allowed.count==1)
                let pending=request(kind,context,tab)
                await wait{window.attachedSheet != nil || pending.count != nil}
                let staleSheet=window.attachedSheet
                await host.setEnabled(id,false)
                if let staleSheet{window.endSheet(staleSheet,returnCode:.alertFirstButtonReturn)}
                await wait{pending.count != nil && window.attachedSheet==nil}
                check("kind-\(kind)-disabled-context-denies",staleSheet != nil && host.contexts[id]==nil && pending.count==0)
                await host.setEnabled(id,true)
                let replay=request(kind,context,tab)
                check("kind-\(kind)-replaced-context-no-prompt",host.contexts[id] !== context && replay.count==0 && window.attachedSheet==nil)
            }
            guard let context=host.contexts[id],let privateID=privateSession.state.selectedTabID else{throw ExtensionValidationError.invalid("Missing private fixture context")}
            let privateReply=request(0,context,privateSession.bridge(privateID))
            check("private-window-denied",privateReply.count==0 && privateSession.window?.attachedSheet==nil)
            let closing=session.newTab(),closingBridge=session.bridge(closing)
            let pending=request(0,context,closingBridge)
            await wait{window.attachedSheet != nil || pending.count != nil}
            let sheet=window.attachedSheet
            session.close(closing,ask:false)
            if let sheet{window.endSheet(sheet,returnCode:.alertFirstButtonReturn)}
            await wait{pending.count != nil && window.attachedSheet==nil}
            check("closed-requesting-tab-denied",sheet != nil && pending.count==0)
            let closed=request(0,context,closingBridge)
            check("closed-tab-cannot-create-prompt",closed.count==0 && window.attachedSheet==nil)
        } catch {check("setup",false,error.localizedDescription)}
        await host.remove(id)
        return results
    }
}
