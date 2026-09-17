import AppKit
import WebKit
import SereinCore

@MainActor final class ExtensionWindow: NSObject, WKWebExtensionWindow {
    weak var session: BrowserSession?
    init(session: BrowserSession) {self.session=session}
    func tabs(for context: WKWebExtensionContext) -> [any WKWebExtensionTab] {guard let session,!session.state.isPrivate else{return []};return session.state.tabs.map{session.bridge($0.id)}}
    func activeTab(for context: WKWebExtensionContext) -> (any WKWebExtensionTab)? {guard let session,let id=session.state.selectedTabID else{return nil};return session.bridge(id)}
    func isPrivate(for context: WKWebExtensionContext) -> Bool {session?.state.isPrivate ?? true}
    func frame(for context: WKWebExtensionContext) -> CGRect {session?.window?.frame ?? .zero}
    func screenFrame(for context: WKWebExtensionContext) -> CGRect {session?.window?.screen?.frame ?? .zero}
    func windowType(for context: WKWebExtensionContext) -> WKWebExtension.WindowType {.normal}
    func windowState(for context: WKWebExtensionContext) -> WKWebExtension.WindowState {
        guard let window=session?.window else{return .normal}
        return window.isMiniaturized ? .minimized : window.styleMask.contains(.fullScreen) ? .fullscreen : .normal
    }
    func focus(for context: WKWebExtensionContext,completionHandler: @escaping ((any Error)?)->Void) {session?.window?.makeKeyAndOrderFront(nil);completionHandler(nil)}
    func close(for context: WKWebExtensionContext,completionHandler: @escaping ((any Error)?)->Void) {session?.window?.performClose(nil);completionHandler(nil)}
    func setFrame(_ frame: CGRect,for context: WKWebExtensionContext,completionHandler: @escaping ((any Error)?)->Void) {session?.window?.setFrame(frame,display:true);completionHandler(nil)}
    func setWindowState(_ state:WKWebExtension.WindowState,for context:WKWebExtensionContext,completionHandler:@escaping ((any Error)?)->Void) {
        guard let window=session?.window else{completionHandler(ExtensionValidationError.invalid("Window no longer exists."));return}
        switch state {
        case .minimized:window.miniaturize(nil)
        case .fullscreen:if !window.styleMask.contains(.fullScreen){window.toggleFullScreen(nil)}
        case .maximized:if window.isMiniaturized{window.deminiaturize(nil)};if !window.isZoomed{window.zoom(nil)}
        case .normal:if window.isMiniaturized{window.deminiaturize(nil)};if window.styleMask.contains(.fullScreen){window.toggleFullScreen(nil)};if window.isZoomed{window.zoom(nil)}
        @unknown default:completionHandler(ExtensionValidationError.invalid("Unsupported window state."));return
        }
        completionHandler(nil)
    }
}
@MainActor final class ExtensionTab: NSObject, WKWebExtensionTab {
    let id: UUID
    weak var session: BrowserSession?
    init(id: UUID,session: BrowserSession) {self.id=id;self.session=session}
    private var tab: BrowserTab? {session?.state.tabs.first{$0.id==id}}
    func window(for context: WKWebExtensionContext) -> (any WKWebExtensionWindow)? {session?.extensionWindow}
    func indexInWindow(for context: WKWebExtensionContext) -> Int {session?.state.tabs.firstIndex{$0.id==id} ?? NSNotFound}
    func webView(for context: WKWebExtensionContext) -> WKWebView? {session?.runtime(id).webView}
    func title(for context: WKWebExtensionContext) -> String? {tab?.title}
    func url(for context: WKWebExtensionContext) -> URL? {tab.flatMap{URL(string:$0.url)}}
    func isPinned(for context: WKWebExtensionContext) -> Bool {tab?.kind != .regular}
    func isSelected(for context: WKWebExtensionContext) -> Bool {session?.state.selectedTabID==id}
    func isLoadingComplete(for context: WKWebExtensionContext) -> Bool {!(session?.runtimes[id]?.isLoading ?? false)}
    func shouldBypassPermissions(for context: WKWebExtensionContext) -> Bool {false}
    func shouldGrantPermissionsOnUserGesture(for context: WKWebExtensionContext) -> Bool {true}
    func size(for context: WKWebExtensionContext) -> CGSize {session?.runtimes[id]?.webView.bounds.size ?? .zero}
    func zoomFactor(for context: WKWebExtensionContext) -> Double {Double(session?.runtime(id).webView.pageZoom ?? 1)}
    func setZoomFactor(_ value: Double,for context: WKWebExtensionContext,completionHandler: @escaping ((any Error)?)->Void) {session?.runtime(id).webView.pageZoom=min(5,max(0.25,value));completionHandler(nil)}
    func activate(for context: WKWebExtensionContext,completionHandler: @escaping ((any Error)?)->Void) {session?.select(id);completionHandler(nil)}
    func setSelected(_ selected: Bool,for context: WKWebExtensionContext,completionHandler: @escaping ((any Error)?)->Void) {
        if selected {session?.select(id);completionHandler(nil)} else {completionHandler(ExtensionValidationError.invalid("Tab multiselection is not implemented."))}
    }
    func setPinned(_ pinned: Bool,for context: WKWebExtensionContext,completionHandler: @escaping ((any Error)?)->Void) {session?.setKind(id,pinned ? .pinned : .regular);completionHandler(nil)}
    func loadURL(_ url: URL,for context: WKWebExtensionContext,completionHandler: @escaping ((any Error)?)->Void) {
        guard ["http","https","about"].contains(url.scheme ?? "") || session?.extensions?.controller.extensionContext(for:url)===context else {completionHandler(ExtensionValidationError.invalid("This URL scheme is not permitted."));return}
        session?.runtime(id).load(url);completionHandler(nil)
    }
    func reload(fromOrigin: Bool,for context: WKWebExtensionContext,completionHandler: @escaping ((any Error)?)->Void) {if fromOrigin {session?.runtime(id).webView.reloadFromOrigin()} else {session?.runtime(id).webView.reload()};completionHandler(nil)}
    func goBack(for context: WKWebExtensionContext,completionHandler: @escaping ((any Error)?)->Void) {session?.runtime(id).webView.goBack();completionHandler(nil)}
    func goForward(for context: WKWebExtensionContext,completionHandler: @escaping ((any Error)?)->Void) {session?.runtime(id).webView.goForward();completionHandler(nil)}
    func close(for context: WKWebExtensionContext,completionHandler: @escaping ((any Error)?)->Void) {session?.close(id);completionHandler(nil)}
    func duplicate(using configuration: WKWebExtension.TabConfiguration,for context: WKWebExtensionContext,completionHandler: @escaping ((any WKWebExtensionTab)?,(any Error)?)->Void) {
        guard let session,let tab else{completionHandler(nil,ExtensionValidationError.invalid("The tab no longer exists."));return}
        let new=session.newTab(url:configuration.url?.absoluteString ?? tab.url,select:configuration.shouldBeActive);completionHandler(session.bridge(new),nil)
    }
}
