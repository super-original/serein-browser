import Foundation
import WebKit

/// Exercise the sender boundary used by real extensions to trust options messages.
@MainActor enum ExtensionSenderVerification {
    static func resourcePage(session:BrowserSession,context:WKWebExtensionContext,name:String) async->[RuntimeVerification.Result] {
        let owner=session.state.selectedTabID,url=context.baseURL.appendingPathComponent("popup.html")
        let tab=session.newTab(url:url.absoluteString),view=session.runtime(tab).webView
        defer{session.close(tab,ask:false);if let owner{session.select(owner)}}
        for _ in 0..<100 {if view.url==url && !view.isLoading{break};try? await Task.sleep(for:.milliseconds(50))}
        return await run(view:view,context:context,name:name)
    }
    static func run(view:WKWebView,context:WKWebExtensionContext,name:String) async->[RuntimeVerification.Result] {
        let reply=try? await view.callAsyncJavaScript("""
        try {
          return await Promise.race([
            browser.runtime.sendMessage({type:'sender-probe'}),
            new Promise(resolve=>setTimeout(()=>resolve({error:'timeout'}),3000))
          ]);
        } catch(error){return {error:String(error)};}
        """,arguments:[:],in:nil,contentWorld:.page) as? [String:Any]
        let base=context.baseURL.absoluteString.lowercased().trimmingCharacters(in:CharacterSet(charactersIn:"/"))
        let origin=reply?["origin"] as? String
        // Firefox may omit origin; a supplied origin must represent this extension.
        let originValid=reply != nil && reply?["error"]==nil && (reply?["origin"] is NSNull || origin?.lowercased()==base)
        return [
            .init(name:name+"-resource-sender-url",passed:reply?["senderURL"] as? String==view.url?.absoluteString && reply?["backgroundURL"] as? String==context.baseURL.absoluteString,detail:String(describing:reply)),
            .init(name:name+"-resource-sender-trusted-origin",passed:originValid,detail:String(describing:reply))
        ]
    }
}
