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
        return window.isMiniaturized ? .minimized : window.styleMask.contains(.fullScreen) ? .fullscreen : window.isZoomed ? .maximized : .normal
    }
    func focus(for context: WKWebExtensionContext,completionHandler: @escaping ((any Error)?)->Void) {session?.window?.makeKeyAndOrderFront(nil);completionHandler(nil)}
    func close(for context: WKWebExtensionContext,completionHandler: @escaping ((any Error)?)->Void) {session?.window?.performClose(nil);completionHandler(nil)}
    func setFrame(_ frame: CGRect,for context: WKWebExtensionContext,completionHandler: @escaping ((any Error)?)->Void) {guard let window=session?.window,frame.origin.x.isFinite,frame.origin.y.isFinite,frame.width.isFinite,frame.height.isFinite,frame.width>=640,frame.height>=400 else{completionHandler(ExtensionValidationError.invalid("A finite window frame of at least 640 by 400 is required."));return};window.setFrame(frame,display:true);completionHandler(nil)}
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
    func webView(for context: WKWebExtensionContext) -> WKWebView? {session?.runtimes[id]?.loadedWebView}
    func title(for context: WKWebExtensionContext) -> String? {tab?.title}
    func url(for context: WKWebExtensionContext) -> URL? {tab.flatMap{URL(string:$0.url)}}
    func isPinned(for context: WKWebExtensionContext) -> Bool {tab?.kind != .regular}
    func isSelected(for context: WKWebExtensionContext) -> Bool {
        let value=session?.tabSelection.ids.contains(id) ?? false
        ExtensionSelectionTrace.record("query",id:id,value:value,count:session?.tabSelection.ids.count ?? 0)
        return value
    }
    func isLoadingComplete(for context: WKWebExtensionContext) -> Bool {!(session?.runtimes[id]?.isLoading ?? false)}
    func shouldBypassPermissions(for context: WKWebExtensionContext) -> Bool {false}
    func shouldGrantPermissionsOnUserGesture(for context: WKWebExtensionContext) -> Bool {true}
    func size(for context: WKWebExtensionContext) -> CGSize {session?.runtimes[id]?.loadedWebView?.bounds.size ?? .zero}
    func zoomFactor(for context: WKWebExtensionContext) -> Double {Double(session?.runtimes[id]?.loadedWebView?.pageZoom ?? 1)}
    func setZoomFactor(_ value: Double,for context: WKWebExtensionContext,completionHandler: @escaping ((any Error)?)->Void) {guard let session,tab != nil,session.runtime(id).setZoom(value) else{completionHandler(ExtensionValidationError.invalid("The tab is unavailable or the zoom factor is outside 0.25–5 (0 resets)."));return};completionHandler(nil)}
    func activate(for context: WKWebExtensionContext,completionHandler: @escaping ((any Error)?)->Void) {session?.select(id,preservingSelection:true);completionHandler(nil)}
    func setSelected(_ selected: Bool,for context: WKWebExtensionContext,completionHandler: @escaping ((any Error)?)->Void) {
        ExtensionSelectionTrace.record("set",id:id,value:selected,count:session?.tabSelection.ids.count ?? 0)
        if session?.setHighlighted(id,selected)==true {completionHandler(nil)} else {completionHandler(ExtensionValidationError.invalid("The tab no longer exists."))}
    }
    func setPinned(_ pinned: Bool,for context: WKWebExtensionContext,completionHandler: @escaping ((any Error)?)->Void) {session?.setKind(id,pinned ? .pinned : .regular);completionHandler(nil)}
    func loadURL(_ url: URL,for context: WKWebExtensionContext,completionHandler: @escaping ((any Error)?)->Void) {
        guard session?.extensions?.canOpen(url,for:context) == true else {completionHandler(ExtensionValidationError.invalid("This URL scheme is not permitted."));return}
        session?.runtime(id).load(url);completionHandler(nil)
    }
    func reload(fromOrigin: Bool,for context: WKWebExtensionContext,completionHandler: @escaping ((any Error)?)->Void) {session?.runtime(id).reload(fromOrigin:fromOrigin);completionHandler(nil)}
    func goBack(for context: WKWebExtensionContext,completionHandler: @escaping ((any Error)?)->Void) {session?.runtime(id).goBack();completionHandler(nil)}
    func goForward(for context: WKWebExtensionContext,completionHandler: @escaping ((any Error)?)->Void) {session?.runtime(id).goForward();completionHandler(nil)}
    func close(for context: WKWebExtensionContext,completionHandler: @escaping ((any Error)?)->Void) {
        guard let session else{completionHandler(ExtensionValidationError.invalid("The tab no longer exists."));return}
        session.close(id) {closed in completionHandler(closed ? nil : ExtensionValidationError.invalid("Closing the tab was cancelled or its document changed."))}
    }
    func duplicate(using configuration: WKWebExtension.TabConfiguration,for context: WKWebExtensionContext,completionHandler: @escaping ((any WKWebExtensionTab)?,(any Error)?)->Void) {
        guard let session,let tab else{completionHandler(nil,ExtensionValidationError.invalid("The tab no longer exists."));return}
        let destination=configuration.url ?? URL(string:tab.url)
        guard let destination,session.extensions?.canOpen(destination,for:context)==true else{completionHandler(nil,ExtensionValidationError.invalid("This duplicate URL is not permitted."));return}
        let new=session.newTab(url:destination.absoluteString,select:configuration.shouldBeActive)
        if configuration.shouldBePinned || tab.kind != .regular {session.setKind(new,.pinned)}
        completionHandler(session.bridge(new),nil)
    }
}

/// Bounded diagnostic recording, enabled only by the deterministic test launch.
@MainActor enum ExtensionSelectionTrace {
    struct Entry:Codable {let operation:String;let id:UUID;let value:Bool;let selectedCount:Int}
    static var entries:[Entry]=[]
    static func record(_ operation:String,id:UUID,value:Bool,count:Int) {
        guard ProcessInfo.processInfo.arguments.contains("--integration-test"),entries.count<2000 else{return}
        entries.append(Entry(operation:operation,id:id,value:value,selectedCount:count))
    }
    static func save(to root:URL) {
        try? JSONEncoder().encode(entries).write(to:root.appendingPathComponent("extension-selection-trace.json"),options:.atomic)
    }
}
