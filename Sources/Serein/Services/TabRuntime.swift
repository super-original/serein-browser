import AppKit
import WebKit
import Observation
import SereinCore

@MainActor @Observable final class TabRuntime: NSObject {
    private static let editScriptSource="document.addEventListener('input',()=>window.webkit.messageHandlers.edited.postMessage(true),{capture:true,once:true});"
    let id: UUID
    var title="New Tab"
    var isLoading=false
    var progress=0.0
    var canGoBack=false
    var canGoForward=false
    var failure: String?
    private var provisionalURL: URL?
    private(set) var failedURL: URL?
    var hasUserEdits=false
    var crashed=false
    private(set) var documentID=UUID()
    @ObservationIgnored weak var session: BrowserSession?
    @ObservationIgnored private var observations: [NSKeyValueObservation] = []
    @ObservationIgnored private var initialConfiguration: WKWebViewConfiguration?
    @ObservationIgnored private var storedView: WKWebView?
    @ObservationIgnored private var editBridge: EditBridge?
    @ObservationIgnored private var permittedFileRoot: URL?
    @ObservationIgnored private var pendingPageFocus=false
    @ObservationIgnored private weak var replacedResponder:NSResponder?
    private(set) var viewRevision=0
    @ObservationIgnored private var extensionReloadState:Any?
    @ObservationIgnored private var extensionReloadZoom:CGFloat=1
    @ObservationIgnored private var awaitingExtensionReload=false
    @ObservationIgnored private var extensionHistoryAfterPreload:Any?
    var hasPendingExtensionReload:Bool {awaitingExtensionReload}
    @ObservationIgnored private var configurationContext: WKWebExtensionContext?
    var loadedWebView:WKWebView? {storedView}
    var webView: WKWebView {
        if let storedView {return storedView}
        let url=session?.state.tabs.first(where:{$0.id==id}).flatMap{URL(string:$0.url)}
        let view=makeView(for:url)
        if let url,url.absoluteString != "about:blank" {
            provisionalURL=url
            if awaitingExtensionReload {
                if configurationContext != nil {
                    awaitingExtensionReload=false
                    let state=extensionReloadState;extensionReloadState=nil
                    view.pageZoom=extensionReloadZoom
                    if let state {prepareHistoryRestore(state,in:view,at:url)} else {view.load(url)}
                } else {
                    failedURL=url;failure="This extension is disabled. Re-enable it to reload this page."
                }
            } else {view.load(url)}
        }
        return view
    }
    private func makeView(for url:URL?) -> WKWebView {
        let context=url.flatMap{session?.extensions?.controller.extensionContext(for:$0)}
        configurationContext=context
        let config=context?.webViewConfiguration ?? initialConfiguration ?? WKWebViewConfiguration()
        let sharesConfiguration=context != nil || initialConfiguration != nil
        initialConfiguration=nil
        // Extension and popup configurations may share a user-content controller. Keep this tab's
        // native message handler private to its view without altering engine settings.
        if sharesConfiguration {
            let content=WKUserContentController()
            for script in config.userContentController.userScripts where script.source != Self.editScriptSource {content.addUserScript(script)}
            config.userContentController=content
        }
        if let session {config.websiteDataStore=session.dataStore;config.webExtensionController=session.extensions?.controller}
        config.preferences.isElementFullscreenEnabled=true
        config.preferences.javaScriptCanOpenWindowsAutomatically=false
        let bridge=EditBridge(runtime:self);editBridge=bridge
        config.userContentController.add(bridge,contentWorld:.world(name:"SereinPageState"),name:"edited")
        config.userContentController.addUserScript(WKUserScript(source:Self.editScriptSource,injectionTime:.atDocumentStart,forMainFrameOnly:false,in:.world(name:"SereinPageState")))
        let view=WKWebView(frame:.zero,configuration:config);storedView=view
        view.wantsLayer=true
        view.navigationDelegate=self;view.uiDelegate=self;view.allowsBackForwardNavigationGestures=true
        observations=[view.observe(\.title,options:[.new]){[weak self] _,_ in Task {@MainActor in self?.synchronize()}},view.observe(\.url,options:[.new]){[weak self] _,_ in Task {@MainActor in self?.synchronize()}},view.observe(\.isLoading,options:[.new]){[weak self] _,_ in Task {@MainActor in self?.synchronize()}},view.observe(\.estimatedProgress,options:[.new]){[weak self] _,_ in Task {@MainActor in self?.synchronize()}}]
        return view
    }
    init(id: UUID, session: BrowserSession, configuration: WKWebViewConfiguration? = nil) {self.id=id;self.session=session;initialConfiguration=configuration;super.init()}
    func captureExtensionReloadState(for context:WKWebExtensionContext) -> Bool {
        guard configurationContext === context else{return false}
        extensionReloadState=extensionHistoryAfterPreload ?? storedView?.interactionState
        extensionReloadZoom=storedView?.pageZoom ?? 1
        awaitingExtensionReload=true
        if let current=storedView,let responder=current.window?.firstResponder as? NSView {
            pendingPageFocus = responder === current || responder.isDescendant(of:current)
            replacedResponder=responder
        }
        // Release every old extension page before a new context derives related
        // views. Keep only public opaque state, never the old view/configuration.
        dispose();configurationContext=nil;isLoading=false;progress=0;viewRevision += 1
        return true
    }
    private func view(for url:URL,restoringCurrentPage:Bool=false) -> WKWebView {
        let current=webView
        let context=session?.extensions?.controller.extensionContext(for:url)
        guard configurationContext !== context || awaitingExtensionReload else{return current}
        let saved=awaitingExtensionReload
        let state=extensionReloadState ?? current.interactionState
        let zoom=saved ? extensionReloadZoom : current.pageZoom
        extensionReloadState=nil;awaitingExtensionReload=false
        let responder=current.window?.firstResponder as? NSView
        let restoreFocus=responder.map{$0 === current || $0.isDescendant(of:current)} ?? false
        dispose()
        pendingPageFocus=pendingPageFocus || restoreFocus
        if let responder {replacedResponder=responder}
        let replacement=makeView(for:url)
        if saved || current.backForwardList.currentItem != nil,let state {
            if saved,restoringCurrentPage,context != nil {
                prepareHistoryRestore(state,in:replacement,at:url)
            } else {
                replacement.interactionState=state
                // Restore the list, then let the caller request its destination.
                if !restoringCurrentPage {replacement.stopLoading()}
            }
        }
        replacement.pageZoom=zoom
        viewRevision += 1
        return replacement
    }
    private func prepareHistoryRestore(_ state:Any,in view:WKWebView,at url:URL) {
        extensionHistoryAfterPreload=state
        // A real context resource is required to initialize WebKit's extension
        // loader. Navigation preferences suppress this transient page's scripts.
        view.load(url)
    }
    func load(_ url: URL) {
        extensionHistoryAfterPreload=nil
        let view=view(for:url)
        documentID=UUID();provisionalURL=url;failedURL=nil;failure=nil;crashed=false;view.load(url)
    }
    @discardableResult func setZoom(_ value:Double) -> Bool {
        guard value.isFinite,value==0 || (0.25...5).contains(value) else{return false}
        let factor=value==0 ? 1 : value
        let view=webView
        guard view.pageZoom != factor else{return true}
        view.pageZoom=factor
        if let session {session.extensions?.controller.didChangeTabProperties(.zoomFactor,for:session.bridge(id))}
        return true
    }
    func goBack(){traverse(-1)}
    func goForward(){traverse(1)}
    private func traverse(_ offset:Int) {
        if awaitingExtensionReload,let url=session?.state.tabs.first(where:{$0.id==id}).flatMap({URL(string:$0.url)}) {_=view(for:url)}
        guard let item=webView.backForwardList.item(at:offset) else{return}
        provisionalURL=item.url
        let view=view(for:item.url)
        if let restored=view.backForwardList.item(at:offset){view.go(to:restored)}
    }
    func reload(fromOrigin:Bool=false) {
        guard let url=failedURL ?? storedView?.url ?? session?.state.tabs.first(where:{$0.id==id}).flatMap({URL(string:$0.url)}) else{webView.reload();return}
        if url.isFileURL {openFile(url);return}
        documentID=UUID();provisionalURL=url;failedURL=nil;failure=nil;crashed=false
        if storedView==nil,awaitingExtensionReload,session?.extensions?.controller.extensionContext(for:url) != nil {
            _=webView
            return
        }
        let previous=webView
        let restoring=(awaitingExtensionReload && extensionReloadState != nil) || (previous.backForwardList.currentItem?.url==url && previous.interactionState != nil)
        let view=view(for:url,restoringCurrentPage:restoring)
        if view !== previous,restoring {return}
        if view.backForwardList.currentItem?.url==url {if fromOrigin {view.reloadFromOrigin()} else {view.reload()}} else {view.load(url)}
    }
    func openFile(_ url:URL) {
        let root=url.deletingLastPathComponent().resolvingSymlinksInPath().standardizedFileURL
        permittedFileRoot=root;documentID=UUID();provisionalURL=url;failedURL=nil;failure=nil;crashed=false
        view(for:url).loadFileURL(url,allowingReadAccessTo:root)
    }
    func restoreFocusIfNeeded(in window:NSWindow?) {
        guard pendingPageFocus,let window,storedView?.window===window else{return}
        pendingPageFocus=false
        if window.firstResponder is NSTextView,window.firstResponder !== replacedResponder {return}
        session?.focusContent(ifSelected:id)
        replacedResponder=nil
    }
    func synchronize() {
        guard let view=storedView else{return}
        title=view.title ?? "New Tab";isLoading=view.isLoading;progress=view.estimatedProgress;canGoBack=view.canGoBack;canGoForward=view.canGoForward
        session?.update(id,url:(failedURL ?? provisionalURL ?? view.url)?.absoluteString,title:view.title)
    }
    func dispose() {
        documentID=UUID()
        extensionHistoryAfterPreload=nil
        observations=[];storedView?.stopLoading();storedView?.navigationDelegate=nil;storedView?.uiDelegate=nil
        storedView?.configuration.userContentController.removeScriptMessageHandler(forName:"edited",contentWorld:.world(name:"SereinPageState"))
        storedView?.removeFromSuperview();storedView=nil;editBridge=nil
    }
}
@MainActor private final class EditBridge: NSObject, WKScriptMessageHandler {
    weak var runtime: TabRuntime?
    init(runtime: TabRuntime) {self.runtime=runtime}
    func userContentController(_ userContentController: WKUserContentController,didReceive message: WKScriptMessage) {
        guard let runtime,message.webView === runtime.loadedWebView,message.body as? Bool == true else{return}
        runtime.hasUserEdits=true
    }
}
extension TabRuntime: WKNavigationDelegate {
    func webView(_ webView: WKWebView,didStartProvisionalNavigation navigation: WKNavigation!) {guard webView === storedView else{return};documentID=UUID();failedURL=nil;failure=nil;crashed=false;synchronize()}
    func webView(_ webView: WKWebView,didCommit navigation: WKNavigation!) {guard webView === storedView else{return};provisionalURL=nil;failedURL=nil;hasUserEdits=false;synchronize()}
    func webView(_ webView: WKWebView,didFinish navigation: WKNavigation!) {
        guard webView === storedView else{return}
        if let state=extensionHistoryAfterPreload {
            extensionHistoryAfterPreload=nil
            // Establish the recreated context's document first, then replace the
            // transient preload list with the saved opaque history. Never append
            // a recovery request after restoring that history.
            webView.interactionState=state
            return
        }
        synchronize()
        if let session,let url=webView.url {session.manager?.library.visit(title:title,url:url.absoluteString,isPrivate:session.state.isPrivate)}
    }
    func webView(_ webView: WKWebView,didFailProvisionalNavigation navigation: WKNavigation!,withError error: Error) {if webView === storedView {failed(error)}}
    func webView(_ webView: WKWebView,didFail navigation: WKNavigation!,withError error: Error) {if webView === storedView {failed(error)}}
    private func failed(_ error: Error) {
        let error=error as NSError
        if ProcessInfo.processInfo.arguments.contains("--integration-test"),configurationContext != nil {
            ExtensionNavigationTrace.record("EXTENSION_NAV_ERROR tab=\(id) revision=\(viewRevision) domain=\(error.domain) code=\(error.code) url=\(String(describing:storedView?.url)) intended=\(String(describing:provisionalURL))")
        }
        if error.domain != NSURLErrorDomain || error.code != NSURLErrorCancelled {
            failedURL=(error.userInfo[NSURLErrorFailingURLErrorKey] as? URL) ?? provisionalURL ?? storedView?.url
            provisionalURL=nil;failure=error.localizedDescription
        }
        synchronize()
    }
    func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {guard webView === storedView else{return};documentID=UUID();failedURL=provisionalURL ?? webView.url;provisionalURL=nil;crashed=true;failure="The web content process stopped. Reload to recover this tab.";isLoading=false}
    func webView(_ webView:WKWebView,decidePolicyFor action:WKNavigationAction,preferences:WKWebpagePreferences,decisionHandler:@escaping @MainActor @Sendable (WKNavigationActionPolicy,WKWebpagePreferences)->Void) {
        if webView === storedView,configurationContext != nil {
            preferences.allowsContentJavaScript=extensionHistoryAfterPreload == nil
        }
        self.webView(webView,decidePolicyFor:action) {policy in decisionHandler(policy,preferences)}
    }
    func webView(_ webView: WKWebView,decidePolicyFor action: WKNavigationAction,decisionHandler: @escaping @MainActor @Sendable (WKNavigationActionPolicy)->Void) {
        guard webView === storedView,let url=action.request.url else {decisionHandler(.cancel);return}
        if action.navigationType == .linkActivated,action.modifierFlags.intersection([.option,.command,.control,.shift]) == .option,
           !action.shouldPerformDownload,["http","https"].contains(url.scheme?.lowercased() ?? ""),
           let session,session.state.visibleTabs.contains(where:{$0.id==id}) {
            decisionHandler(.cancel)
            session.openGlance(url,from:id)
            return
        }
        let destinationContext=session?.extensions?.controller.extensionContext(for:url)
        if ProcessInfo.processInfo.arguments.contains("--integration-test"),url.scheme=="webkit-extension" || configurationContext != nil {
            ExtensionNavigationTrace.record("EXTENSION_NAV tab=\(id) revision=\(viewRevision) type=\(action.navigationType.rawValue) target=\(url) configured=\(String(describing:configurationContext?.baseURL)) registered=\(String(describing:destinationContext?.baseURL)) sameContext=\(configurationContext === destinationContext) source=\(action.sourceFrame.securityOrigin.protocol)://\(action.sourceFrame.securityOrigin.host)")
        }
        if action.targetFrame?.isMainFrame==true,!action.shouldPerformDownload,
           configurationContext !== destinationContext,
           destinationContext != nil || ["http","https","about"].contains(url.scheme?.lowercased() ?? "") {
            if let destinationContext,action.navigationType != .backForward,
               session?.extensions?.allowsPageNavigation(to:url,context:destinationContext,from:action.sourceFrame.securityOrigin) != true {
                decisionHandler(.cancel);return
            }
            decisionHandler(.cancel)
            let request=action.request
            let offsets=Array((-webView.backForwardList.backList.count)...webView.backForwardList.forwardList.count)
            let historyOffset=action.navigationType == .backForward ? offsets.sorted{abs($0)<abs($1)}.first{webView.backForwardList.item(at:$0)?.url==url} : nil
            Task { @MainActor [weak self,weak webView] in
                guard let self,let webView,webView === self.storedView else{return}
                self.provisionalURL=url
                let replacement=self.view(for:url)
                if let historyOffset,let item=replacement.backForwardList.item(at:historyOffset) {replacement.go(to:item)}
                else {replacement.load(request)}
            }
            return
        }
        if destinationContext != nil {if action.targetFrame?.isMainFrame==true {provisionalURL=url};decisionHandler(.allow);return}
        if ["http","https","about","blob","data"].contains(url.scheme?.lowercased() ?? "") {
            if !action.shouldPerformDownload,action.targetFrame?.isMainFrame==true {provisionalURL=url}
            decisionHandler(action.shouldPerformDownload ? .download : .allow);return
        }
        if url.isFileURL,let root=permittedFileRoot {
            let path=url.resolvingSymlinksInPath().standardizedFileURL.path
            if path.hasPrefix(root.path+"/") {decisionHandler(.allow);return}
        }
        decisionHandler(.cancel)
        guard action.navigationType == .linkActivated else{return}
        session?.confirm("Open another application?",detail:url.absoluteString,yes:"Open") {allow in if allow {NSWorkspace.shared.open(url)}}
    }
    func webView(_ webView: WKWebView,decidePolicyFor response: WKNavigationResponse,decisionHandler: @escaping @MainActor @Sendable (WKNavigationResponsePolicy)->Void) {
        guard webView === storedView else{decisionHandler(.cancel);return}
        if response.response.url?.scheme=="webkit-extension" {
            ExtensionNavigationTrace.record("EXTENSION_RESPONSE tab=\(id) revision=\(viewRevision) url=\(String(describing:response.response.url)) mime=\(response.response.mimeType ?? "none") displayable=\(response.canShowMIMEType)")
        }
        if !response.canShowMIMEType {provisionalURL=nil;failedURL=nil;synchronize()}
        decisionHandler(response.canShowMIMEType ? .allow : .download)
    }
    func webView(_ webView: WKWebView,navigationAction: WKNavigationAction,didBecome download: WKDownload) {if let session {session.manager?.downloads.add(download,in:session)} else {download.cancel(nil)}}
    func webView(_ webView: WKWebView,navigationResponse: WKNavigationResponse,didBecome download: WKDownload) {if let session {session.manager?.downloads.add(download,in:session)} else {download.cancel(nil)}}
}
