import AppKit
import WebKit
import SereinCore

extension TabRuntime: WKUIDelegate {
    func webView(_ webView: WKWebView,createWebViewWith configuration: WKWebViewConfiguration,for action: WKNavigationAction,windowFeatures: WKWindowFeatures) -> WKWebView? {
        guard webView === loadedWebView,let session,action.targetFrame==nil else{return nil}
        return session.newPopup(action.request.url,from:id,configuration:configuration)
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
        requestSitePermission(in:webView,frame:frame,origin:origin,capabilities:capabilities,decisionHandler:decisionHandler)
    }

    // New public permission delegate in macOS 27. No Core Location proxy or
    // private WebKit selector is needed to mediate the website's request.
    func webView(_ webView:WKWebView,requestGeolocationPermissionFor origin:WKSecurityOrigin,initiatedByFrame frame:WKFrameInfo,decisionHandler:@escaping @MainActor @Sendable (WKPermissionDecision)->Void) {
        requestSitePermission(in:webView,frame:frame,origin:origin,capabilities:[.location],decisionHandler:decisionHandler)
    }

    private func requestSitePermission(in page:WKWebView,frame:WKFrameInfo,origin:WKSecurityOrigin,capabilities:[SiteCapability],decisionHandler:@escaping @MainActor @Sendable (WKPermissionDecision)->Void) {
        guard page === loadedWebView,frame.securityOrigin.protocol==origin.protocol,
              frame.securityOrigin.host==origin.host,frame.securityOrigin.port==origin.port else{decisionHandler(.deny);return}
        var components = URLComponents()
        components.scheme = origin.protocol
        components.host = origin.host
        if origin.port > 0 { components.port = origin.port }
        guard let requestingURL = components.url, let requesting = SiteOrigin(url: requestingURL) else {
            decisionHandler(.deny); return
        }
        let document=documentID
        Task { [weak self,weak page] in
            guard let self,let page,page === self.loadedWebView,self.documentID==document,
                  let token=try? await page.callAsyncJavaScript("""
                  if (location.href !== expectedURL) return null;
                  if (!globalThis.sereinPermissionDocumentToken) globalThis.sereinPermissionDocumentToken = nonce;
                  return globalThis.sereinPermissionDocumentToken;
                  """,arguments:["nonce":UUID().uuidString,"expectedURL":frame.request.url?.absoluteString ?? ""],in:frame,contentWorld:.world(name:"SereinPermissionState")) as? String,
                  page === self.loadedWebView,self.documentID==document else{decisionHandler(.deny);return}
            self.decideSitePermission(requesting:requesting,capabilities:capabilities,validation:{ [weak self,weak page] in
                guard let self,let page,page === self.loadedWebView,self.documentID==document else{return false}
                let current=try? await page.callAsyncJavaScript("return globalThis.sereinPermissionDocumentToken || null;",arguments:[:],in:frame,contentWorld:.world(name:"SereinPermissionState")) as? String
                if ProcessInfo.processInfo.arguments.contains("--integration-test") {
                    print("SITE_PERMISSION frameValidation tokenPresent=\(current != nil) tokenMatches=\(current==token) viewMatches=\(page === self.loadedWebView) documentMatches=\(self.documentID==document)")
                }
                return current==token && page === self.loadedWebView && self.documentID==document
            },decisionHandler:decisionHandler)
        }
    }

    /// Shared by WebKit delegates and the deterministic app-process verification.
    func decideSitePermission(requesting: SiteOrigin, capabilities: [SiteCapability], validation:(@MainActor () async->Bool)?=nil, decisionHandler: @escaping @MainActor @Sendable (WKPermissionDecision) -> Void) {
        guard let session, let window = session.window,
              let page=loadedWebView,let topURL=page.url,let top=SiteOrigin(url:topURL) else {
            decisionHandler(.deny); return
        }
        let document=documentID
        let keys = capabilities.map { SitePermissionKey(topLevel: top, requesting: requesting, capability: $0) }
        switch session.sitePermissions.policy.decision(for: keys) {
        case .allow:
            if let validation {
                Task { [weak self,weak page,weak session] in
                    let valid=await validation()
                    guard let self,let page,let session,valid,self.session === session,
                          session.runtimes[self.id] === self,self.loadedWebView === page,self.documentID==document,
                          session.sitePermissions.policy.decision(for:keys) == .allow else{decisionHandler(.deny);return}
                    decisionHandler(.grant)
                }
            } else {decisionHandler(.grant)}
            return
        case .deny: decisionHandler(.deny); return
        case .ask: break
        }
        // Do not replace another sheet or stack permission prompts behind it.
        guard window.attachedSheet == nil else { decisionHandler(.deny); return }
        let alert = NSAlert()
        alert.messageText = "Allow access to " + capabilities.map(\.rawValue).joined(separator: " and ") + "?"
        alert.informativeText = "Requesting site: \(requesting.key)\nTop-level site: \(top.key)"
        alert.addButton(withTitle: "Allow Once")
        alert.addButton(withTitle: "Deny")
        alert.addButton(withTitle: session.state.isPrivate ? "Allow for This Private Window" : "Always Allow for This Site")
        alert.beginSheetModal(for: window) { [weak self, weak session] response in
            guard let self,let session,response == .alertFirstButtonReturn || response == .alertThirdButtonReturn else{decisionHandler(.deny);return}
            let finish:@MainActor (Bool)->Void = {valid in
                if ProcessInfo.processInfo.arguments.contains("--integration-test") {
                    print("SITE_PERMISSION consent valid=\(valid) sessionMatches=\(self.session === session) runtimeMatches=\(session.runtimes[self.id] === self) documentMatches=\(self.documentID==document) viewMatches=\(self.loadedWebView === page) originMatches=\(page.url.flatMap(SiteOrigin.init(url:))==top)")
                }
                guard valid,self.session === session,session.runtimes[self.id] === self,
                      self.documentID==document,self.loadedWebView === page,page.url.flatMap(SiteOrigin.init(url:))==top else{decisionHandler(.deny);return}
                if response == .alertThirdButtonReturn {session.sitePermissions.set(.allow,for:keys)}
                decisionHandler(.grant)
            }
            if let validation {Task{finish(await validation())}} else {finish(true)}
        }
    }
}
