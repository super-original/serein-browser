import AppKit
import Observation
import SereinCore

@MainActor @Observable final class BrowserManager {
    var windows: [BrowserWindowController] = []
    var restorationError: String?
    let library: LibraryStore
    let downloads=DownloadStore()
    let extensions: ExtensionHost
    @ObservationIgnored private var saveTask: Task<Void,Never>?
    @ObservationIgnored lazy var menu=BrowserMenu(manager:self)
    let root: URL
    init(root: URL) {
        self.root=root;library=LibraryStore(root:root);extensions=ExtensionHost(root:root.appendingPathComponent("Extensions"));extensions.manager=self
    }
    var active: BrowserSession? {windows.first{$0.window?.isKeyWindow==true}?.session ?? windows.last?.session}
    func restore() {
        let file=root.appendingPathComponent("session.json")
        if FileManager.default.fileExists(atPath:file.path) {
            do {let saved=try SavedSession.decode(Data(contentsOf:file));for state in saved.windows {newWindow(state:state)}}
            catch {restorationError="The saved session could not be read. It has been preserved for recovery: \(error.localizedDescription)";try? FileManager.default.copyItem(at:file,to:root.appendingPathComponent("session-recovery-\(Int(Date().timeIntervalSince1970)).json"))}
        }
        if windows.isEmpty {newWindow()}
    }
    @discardableResult func newWindow(isPrivate: Bool = false,state: BrowserWindowState? = nil) -> BrowserSession {
        let session=BrowserSession(state:state ?? BrowserWindowState(isPrivate:isPrivate),manager:self)
        let controller=BrowserWindowController(session:session);windows.append(controller)
        session.extensionWindow=ExtensionWindow(session:session)
        controller.showWindow(nil);controller.window?.makeKeyAndOrderFront(nil)
        if !session.state.isPrivate,let bridge=session.extensionWindow {extensions.controller.didOpenWindow(bridge);for tab in session.state.tabs{extensions.controller.didOpenTab(session.bridge(tab.id))}}
        scheduleSave();return session
    }
    func windowClosed(_ controller: BrowserWindowController) {
        let session=controller.session
        if let bridge=session.extensionWindow,!session.state.isPrivate {extensions.controller.didCloseWindow(bridge)}
        for runtime in session.runtimes.values {runtime.dispose()}
        session.runtimes=[:];session.extensionTabs=[:]
        windows.removeAll{$0===controller}
        if session.state.isPrivate {downloads.clearFinished(privateMode:true)}
        scheduleSave()
    }
    func moveTab(_ id: UUID,from source: BrowserSession,to destination: BrowserSession? = nil) {
        guard let tab=source.state.tabs.first(where:{$0.id==id}) else{return}
        guard !source.state.isPrivate else {source.error="Moving a live private tab between isolated windows is not supported.";return}
        let target=destination ?? newWindow(isPrivate:false)
        guard target !== source,target.state.isPrivate==source.state.isPrivate else{return}
        // Transfer the live WKWebView and data store only between matching privacy contexts.
        // Private windows intentionally use separate stores, so their transfer is rejected.
        guard !source.state.isPrivate else {source.error="Moving a live private tab between isolated windows is not supported.";return}
        var moved=tab;moved.workspaceID=target.state.activeWorkspaceID
        let oldIndex=source.state.tabs.firstIndex{$0.id==id} ?? 0
        let bridge=source.bridge(id)
        source.state.close(id,remember:false)
        target.state.tabs.append(moved)
        if let runtime=source.runtimes.removeValue(forKey:id) {runtime.session=target;runtime.webView.removeFromSuperview();target.runtimes[id]=runtime}
        source.extensionTabs[id]=nil;bridge.session=target;target.extensionTabs[id]=bridge
        extensions.controller.didMoveTab(bridge,from:oldIndex,in:source.extensionWindow)
        target.select(id);source.state.repair();if let next=source.state.selectedTabID {source.select(next)}
        scheduleSave()
    }
    func scheduleSave() {
        saveTask?.cancel();saveTask=Task {try? await Task.sleep(for:.milliseconds(350));guard !Task.isCancelled else{return};saveNow()}
    }
    func saveNow() {
        do {try SavedSession(windows:windows.map{$0.session.state}).encoded().write(to:root.appendingPathComponent("session.json"),options:.atomic)}
        catch {restorationError="Session could not be saved: \(error.localizedDescription)"}
    }
}
