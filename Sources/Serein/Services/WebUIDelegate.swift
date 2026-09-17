import AppKit
import WebKit

extension TabRuntime: WKUIDelegate {
    func webView(_ webView: WKWebView,createWebViewWith configuration: WKWebViewConfiguration,for action: WKNavigationAction,windowFeatures: WKWindowFeatures) -> WKWebView? {
        guard let session,action.targetFrame==nil else{return nil}
        let id=session.newTab(configuration:configuration)
        return session.runtime(id).webView
    }
    func webViewDidClose(_ webView: WKWebView) {session?.close(id)}
    func webView(_ webView: WKWebView,runJavaScriptAlertPanelWithMessage message: String,initiatedByFrame frame: WKFrameInfo,completionHandler: @escaping ()->Void) {
        guard let window=session?.window else{completionHandler();return}
        let alert=NSAlert();alert.messageText=frame.securityOrigin.host;alert.informativeText=message;alert.addButton(withTitle:"OK")
        alert.beginSheetModal(for:window){_ in completionHandler()}
    }
    func webView(_ webView: WKWebView,runJavaScriptConfirmPanelWithMessage message: String,initiatedByFrame frame: WKFrameInfo,completionHandler: @escaping (Bool)->Void) {
        guard let session else{completionHandler(false);return}
        session.confirm(frame.securityOrigin.host,detail:message,yes:"OK",completion:completionHandler)
    }
    func webView(_ webView: WKWebView,runJavaScriptTextInputPanelWithPrompt prompt: String,defaultText: String?,initiatedByFrame frame: WKFrameInfo,completionHandler: @escaping (String?)->Void) {
        guard let window=session?.window else{completionHandler(nil);return}
        let alert=NSAlert();alert.messageText=frame.securityOrigin.host;alert.informativeText=prompt;alert.addButton(withTitle:"OK");alert.addButton(withTitle:"Cancel")
        let field=NSTextField(string:defaultText ?? "");field.frame=NSRect(x:0,y:0,width:300,height:26);alert.accessoryView=field
        alert.beginSheetModal(for:window){r in completionHandler(r == .alertFirstButtonReturn ? field.stringValue : nil)}
    }
    func webView(_ webView: WKWebView,runOpenPanelWith parameters: WKOpenPanelParameters,initiatedByFrame frame: WKFrameInfo,completionHandler: @escaping ([URL]?)->Void) {
        guard let window=session?.window else{completionHandler(nil);return}
        let panel=NSOpenPanel();panel.allowsMultipleSelection=parameters.allowsMultipleSelection;panel.canChooseDirectories=parameters.allowsDirectories
        panel.beginSheetModal(for:window){result in completionHandler(result == .OK ? panel.urls : nil)}
    }
    func webView(_ webView: WKWebView,requestMediaCapturePermissionFor origin: WKSecurityOrigin,initiatedByFrame frame: WKFrameInfo,type: WKMediaCaptureType,decisionHandler: @escaping (WKPermissionDecision)->Void) {
        guard let session else{decisionHandler(.deny);return}
        let requested=type == .camera ? "camera" : type == .microphone ? "microphone" : "camera and microphone"
        session.confirm("Allow \(origin.host) to use your \(requested)?",detail:"Origin: \(origin.protocol)://\(origin.host):\(origin.port). This request applies to this page only.",yes:"Allow") {allowed in decisionHandler(allowed ? .grant : .deny)}
    }
}
