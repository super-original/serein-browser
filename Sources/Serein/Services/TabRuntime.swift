import AppKit
import WebKit
import Observation
import SereinCore

@MainActor @Observable final class TabRuntime: NSObject {
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
    @ObservationIgnored private let initialConfiguration: WKWebViewConfiguration?
    @ObservationIgnored private var storedView: WKWebView?
    @ObservationIgnored private var editBridge: EditBridge?
    @ObservationIgnored private var permittedFileRoot: URL?
    var webView: WKWebView {
        if let storedView {return storedView}
        let config=initialConfiguration ?? WKWebViewConfiguration()
        if let session {config.websiteDataStore=session.dataStore;config.webExtensionController=session.extensions?.controller}
        config.preferences.isElementFullscreenEnabled=true
        config.preferences.javaScriptCanOpenWindowsAutomatically=false
        let bridge=EditBridge(runtime:self);editBridge=bridge
        config.userContentController.add(bridge,contentWorld:.world(name:"SereinPageState"),name:"edited")
        config.userContentController.addUserScript(WKUserScript(source:"document.addEventListener('input',()=>window.webkit.messageHandlers.edited.postMessage(true),{capture:true,once:true});",injectionTime:.atDocumentStart,forMainFrameOnly:false,in:.world(name:"SereinPageState")))
        let view=WKWebView(frame:.zero,configuration:config);storedView=view
        view.wantsLayer=true
        view.navigationDelegate=self;view.uiDelegate=self;view.allowsBackForwardNavigationGestures=true
        observations=[view.observe(\.title,options:[.new]){[weak self] _,_ in Task {@MainActor in self?.synchronize()}},view.observe(\.url,options:[.new]){[weak self] _,_ in Task {@MainActor in self?.synchronize()}},view.observe(\.isLoading,options:[.new]){[weak self] _,_ in Task {@MainActor in self?.synchronize()}},view.observe(\.estimatedProgress,options:[.new]){[weak self] _,_ in Task {@MainActor in self?.synchronize()}}]
        if let tab=session?.state.tabs.first(where:{$0.id==id}),let url=URL(string:tab.url),tab.url != "about:blank" {view.load(URLRequest(url:url))}
        return view
    }
    init(id: UUID, session: BrowserSession, configuration: WKWebViewConfiguration? = nil) {self.id=id;self.session=session;initialConfiguration=configuration;super.init()}
    func load(_ url: URL) {documentID=UUID();provisionalURL=url;failedURL=nil;failure=nil;crashed=false;webView.load(URLRequest(url:url))}
    func reload() {if let failedURL {if failedURL.isFileURL {openFile(failedURL)} else {load(failedURL)}} else {webView.reload()}}
    func openFile(_ url:URL) {
        let root=url.deletingLastPathComponent().resolvingSymlinksInPath().standardizedFileURL
        permittedFileRoot=root;documentID=UUID();provisionalURL=url;failedURL=nil;failure=nil;crashed=false
        webView.loadFileURL(url,allowingReadAccessTo:root)
    }
    func synchronize() {
        guard let view=storedView else{return}
        title=view.title ?? "New Tab";isLoading=view.isLoading;progress=view.estimatedProgress;canGoBack=view.canGoBack;canGoForward=view.canGoForward
        session?.update(id,url:(failedURL ?? provisionalURL ?? view.url)?.absoluteString,title:view.title)
    }
    func dispose() {
        documentID=UUID()
        observations=[];storedView?.stopLoading();storedView?.navigationDelegate=nil;storedView?.uiDelegate=nil
        storedView?.configuration.userContentController.removeScriptMessageHandler(forName:"edited",contentWorld:.world(name:"SereinPageState"))
        storedView?.removeFromSuperview();storedView=nil;editBridge=nil
    }
}
@MainActor private final class EditBridge: NSObject, WKScriptMessageHandler {
    weak var runtime: TabRuntime?
    init(runtime: TabRuntime) {self.runtime=runtime}
    func userContentController(_ userContentController: WKUserContentController,didReceive message: WKScriptMessage) {runtime?.hasUserEdits=true}
}
extension TabRuntime: WKNavigationDelegate {
    func webView(_ webView: WKWebView,didStartProvisionalNavigation navigation: WKNavigation!) {documentID=UUID();failedURL=nil;failure=nil;crashed=false;synchronize()}
    func webView(_ webView: WKWebView,didCommit navigation: WKNavigation!) {provisionalURL=nil;failedURL=nil;hasUserEdits=false;synchronize()}
    func webView(_ webView: WKWebView,didFinish navigation: WKNavigation!) {
        synchronize()
        if let session,let url=webView.url {session.manager?.library.visit(title:title,url:url.absoluteString,isPrivate:session.state.isPrivate)}
    }
    func webView(_ webView: WKWebView,didFailProvisionalNavigation navigation: WKNavigation!,withError error: Error) {failed(error)}
    func webView(_ webView: WKWebView,didFail navigation: WKNavigation!,withError error: Error) {failed(error)}
    private func failed(_ error: Error) {
        let error=error as NSError
        if error.domain != NSURLErrorDomain || error.code != NSURLErrorCancelled {
            failedURL=(error.userInfo[NSURLErrorFailingURLErrorKey] as? URL) ?? provisionalURL ?? storedView?.url
            provisionalURL=nil;failure=error.localizedDescription
        }
        synchronize()
    }
    func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {documentID=UUID();failedURL=provisionalURL ?? webView.url;provisionalURL=nil;crashed=true;failure="The web content process stopped. Reload to recover this tab.";isLoading=false}
    func webView(_ webView: WKWebView,decidePolicyFor action: WKNavigationAction,decisionHandler: @escaping @MainActor @Sendable (WKNavigationActionPolicy)->Void) {
        guard let url=action.request.url else {decisionHandler(.cancel);return}
        if session?.extensions?.controller.extensionContext(for:url) != nil {if action.targetFrame?.isMainFrame==true {provisionalURL=url};decisionHandler(.allow);return}
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
        if !response.canShowMIMEType {provisionalURL=nil;failedURL=nil;synchronize()}
        decisionHandler(response.canShowMIMEType ? .allow : .download)
    }
    func webView(_ webView: WKWebView,navigationAction: WKNavigationAction,didBecome download: WKDownload) {if let session {session.manager?.downloads.add(download,in:session)} else {download.cancel(nil)}}
    func webView(_ webView: WKWebView,navigationResponse: WKNavigationResponse,didBecome download: WKDownload) {if let session {session.manager?.downloads.add(download,in:session)} else {download.cancel(nil)}}
}
