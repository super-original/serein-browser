import AppKit
import WebKit
import SereinCore

extension TabRuntime: WKUIDelegate {
    func webView(_ webView: WKWebView,createWebViewWith configuration: WKWebViewConfiguration,for action: WKNavigationAction,windowFeatures: WKWindowFeatures) -> WKWebView? {
        guard let session,action.targetFrame==nil else{return nil}
        let id=session.newTab(configuration:configuration)
        return session.runtime(id).webView
    }
    func webViewDidClose(_ webView: WKWebView) {session?.close(id)}
    func webView(_ webView: WKWebView,runJavaScriptAlertPanelWithMessage message: String,initiatedByFrame frame: WKFrameInfo,completionHandler: @escaping @MainActor @Sendable ()->Void) {
        guard let window=session?.window else{completionHandler();return}
        let alert=NSAlert();alert.messageText=frame.securityOrigin.host;alert.informativeText=message;alert.addButton(withTitle:"OK")
        alert.beginSheetModal(for:window){_ in completionHandler()}
    }
    func webView(_ webView: WKWebView,runJavaScriptConfirmPanelWithMessage message: String,initiatedByFrame frame: WKFrameInfo,completionHandler: @escaping @MainActor @Sendable (Bool)->Void) {
        guard let session else{completionHandler(false);return}
        session.confirm(frame.securityOrigin.host,detail:message,yes:"OK",completion:completionHandler)
    }
    func webView(_ webView: WKWebView,runJavaScriptTextInputPanelWithPrompt prompt: String,defaultText: String?,initiatedByFrame frame: WKFrameInfo,completionHandler: @escaping @MainActor @Sendable (String?)->Void) {
        guard let window=session?.window else{completionHandler(nil);return}
        let alert=NSAlert();alert.messageText=frame.securityOrigin.host;alert.informativeText=prompt;alert.addButton(withTitle:"OK");alert.addButton(withTitle:"Cancel")
        let field=NSTextField(string:defaultText ?? "");field.frame=NSRect(x:0,y:0,width:300,height:26);alert.accessoryView=field
        alert.beginSheetModal(for:window){r in completionHandler(r == .alertFirstButtonReturn ? field.stringValue : nil)}
    }
    func webView(_ webView: WKWebView,runOpenPanelWith parameters: WKOpenPanelParameters,initiatedByFrame frame: WKFrameInfo,completionHandler: @escaping @MainActor @Sendable ([URL]?)->Void) {
        guard let window=session?.window else{completionHandler(nil);return}
        let panel=NSOpenPanel();panel.allowsMultipleSelection=parameters.allowsMultipleSelection;panel.canChooseDirectories=parameters.allowsDirectories
        panel.beginSheetModal(for:window){result in completionHandler(result == .OK ? panel.urls : nil)}
    }
    func webView(_ webView: WKWebView,requestMediaCapturePermissionFor origin: WKSecurityOrigin,initiatedByFrame frame: WKFrameInfo,type: WKMediaCaptureType,decisionHandler: @escaping @MainActor @Sendable (WKPermissionDecision)->Void) {
        let capabilities: [SiteCapability]
        switch type {
        case .camera: capabilities = [.camera]
        case .microphone: capabilities = [.microphone]
        case .cameraAndMicrophone: capabilities = [.camera, .microphone]
        @unknown default: decisionHandler(.deny); return
        }
        requestSitePermission(origin: origin, capabilities: capabilities, decisionHandler: decisionHandler)
    }

    // New public permission delegate in macOS 27. No Core Location proxy or
    // private WebKit selector is needed to mediate the website's request.
    func webView(_ webView:WKWebView,requestGeolocationPermissionFor origin:WKSecurityOrigin,initiatedByFrame frame:WKFrameInfo,decisionHandler:@escaping @MainActor @Sendable (WKPermissionDecision)->Void) {
        requestSitePermission(origin: origin, capabilities: [.location], decisionHandler: decisionHandler)
    }

    private func requestSitePermission(origin: WKSecurityOrigin, capabilities: [SiteCapability], decisionHandler: @escaping @MainActor @Sendable (WKPermissionDecision) -> Void) {
        var components = URLComponents()
        components.scheme = origin.protocol
        components.host = origin.host
        if origin.port > 0 { components.port = origin.port }
        guard let session, let window = session.window,
              let topURL = webView.url, let top = SiteOrigin(url: topURL),
              let requestingURL = components.url, let requesting = SiteOrigin(url: requestingURL) else {
            decisionHandler(.deny); return
        }
        let keys = capabilities.map { SitePermissionKey(topLevel: top, requesting: requesting, capability: $0) }
        switch session.sitePermissions.policy.decision(for: keys) {
        case .allow: decisionHandler(.grant); return
        case .deny: decisionHandler(.deny); return
        case .ask: break
        }
        // Do not replace another sheet or stack permission prompts behind it.
        guard window.attachedSheet == nil else { decisionHandler(.deny); return }
        let document = documentID
        let alert = NSAlert()
        alert.messageText = "Allow access to " + capabilities.map(\.rawValue).joined(separator: " and ") + "?"
        alert.informativeText = "Requesting site: \(requesting.key)\nTop-level site: \(top.key)"
        alert.addButton(withTitle: "Allow Once")
        alert.addButton(withTitle: "Deny")
        alert.addButton(withTitle: session.state.isPrivate ? "Allow for This Private Window" : "Always Allow for This Site")
        alert.beginSheetModal(for: window) { [weak self, weak session] response in
            guard let self, let session, self.session === session,
                  session.runtimes[self.id] === self, self.documentID == document,
                  self.webView.url.flatMap(SiteOrigin.init(url:)) == top else {
                decisionHandler(.deny); return
            }
            if response == .alertThirdButtonReturn {
                session.sitePermissions.set(.allow, for: keys)
            }
            decisionHandler(response == .alertFirstButtonReturn || response == .alertThirdButtonReturn ? .grant : .deny)
        }
    }
}
