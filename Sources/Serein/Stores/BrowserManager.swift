import AppKit
import Observation
import WebKit
import SereinCore

@MainActor @Observable final class BrowserManager {
    var windows: [BrowserWindowController] = []
    var restorationError: String?
    let library: LibraryStore
    let downloads:DownloadStore
    let sitePermissions: SitePermissionStore
    let extensions: ExtensionHost
    @ObservationIgnored private var saveTask: Task<Void,Never>?
    @ObservationIgnored lazy var menu=BrowserMenu(manager:self)
    @ObservationIgnored lazy var tabSuspension=TabSuspensionController(manager:self)
    let sidebarDragToken=UUID()
    @ObservationIgnored var restoredNavigation:[UUID:SavedNavigationHistory]=[:]
    static var navigationEngine:String {
        guard let version=Bundle(for:WKWebView.self).object(forInfoDictionaryKey:"CFBundleVersion") as? String,!version.isEmpty else{return ""}
        return ProcessInfo.processInfo.operatingSystemVersionString+"|"+version
    }
    var restoresNavigation:Bool {UserDefaults.standard.bool(forKey:"restoreTabHistory")}
    func setRestoresNavigation(_ enabled:Bool) {
        UserDefaults.standard.set(enabled,forKey:"restoreTabHistory")
        if !enabled {restoredNavigation.removeAll()}
        saveNow()
    }
    let root: URL
    init(root: URL) {
        var storageError:String?
        do {try PrivateFileStore.prepareDirectory(root)}
        catch {storageError="Browser storage could not be secured: \(error.localizedDescription)"}
        self.root=root;sitePermissions=SitePermissionStore(file:root.appendingPathComponent("site-permissions.json"));library=LibraryStore(root:root);downloads=DownloadStore(root:root);extensions=ExtensionHost(root:root.appendingPathComponent("Extensions"));extensions.manager=self
        restorationError=storageError
    }
    var active: BrowserSession? {
        var candidate=NSApp.keyWindow,seen=Set<ObjectIdentifier>()
        while let window=candidate,seen.insert(ObjectIdentifier(window)).inserted {
            if let session=windows.first(where:{$0.window===window})?.session {return session}
            candidate=window.sheetParent
        }
        if let main=NSApp.mainWindow,let session=windows.first(where:{$0.window===main})?.session {return session}
        return windows.last?.session
    }
    func restore() {
        let file=root.appendingPathComponent("session.json")
        if FileManager.default.fileExists(atPath:file.path) {
            do {
                let size=(try file.resourceValues(forKeys:[.fileSizeKey])).fileSize ?? Int.max
                guard size<=32*1024*1024 else{throw PersistenceError.oversizedSession}
                let saved=try SavedSession.decode(Data(contentsOf:file))
                if restoresNavigation {
                    for record in saved.navigationHistory ?? [] where record.engine==Self.navigationEngine {
                        restoredNavigation[record.tabID]=record
                    }
                }
                for state in saved.windows {newWindow(state:state)}
            }
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
        if session.state.isPrivate {downloads.closePrivateWindow(session.state.id)}
        scheduleSave()
    }
    func moveTab(_ id: UUID,from source: BrowserSession,to destination: BrowserSession? = nil) {
        guard source.state.tabs.contains(where:{$0.id==id}) else{return}
        guard !source.state.isPrivate else {source.error="Moving a live private tab between isolated windows is not supported.";return}
        let target=destination ?? newWindow(isPrivate:false)
        guard target !== source,target.state.isPrivate==source.state.isPrivate else{return}
        // Transfer the live WKWebView and data store only between matching privacy contexts.
        // Private windows intentionally use separate stores, so their transfer is rejected.
        guard !source.state.isPrivate else {source.error="Moving a live private tab between isolated windows is not supported.";return}
        let movingIDs=Set(source.state.closingTabIDs(id))
        let moving=source.state.tabs.filter{movingIDs.contains($0.id)}
        let oldIndices=Dictionary(uniqueKeysWithValues:source.state.tabs.enumerated().map{($0.element.id,$0.offset)})
        let bridges=Dictionary(uniqueKeysWithValues:moving.map{($0.id,source.bridge($0.id))})
        source.state.close(id,remember:false)
        for added in source.state.tabs where oldIndices[added.id]==nil {extensions.controller.didOpenTab(source.bridge(added.id))}
        for tab in moving {
            var moved=tab;moved.folderID=nil;moved.workspaceID=target.state.activeWorkspaceID
            if let opener=moved.openerTabID,!movingIDs.contains(opener) {moved.openerTabID=nil}
            if let parent=moved.glanceParentID,!movingIDs.contains(parent){moved.glanceParentID=nil}
            target.state.tabs.append(moved)
            if let runtime=source.runtimes.removeValue(forKey:tab.id) {runtime.session=target;runtime.webView.removeFromSuperview();target.runtimes[tab.id]=runtime}
            source.extensionTabs[tab.id]=nil
            if let bridge=bridges[tab.id] {bridge.session=target;target.extensionTabs[tab.id]=bridge}
        }
        for tab in moving {
            if let bridge=bridges[tab.id] {extensions.controller.didMoveTab(bridge,from:oldIndices[tab.id] ?? 0,in:source.extensionWindow)}
        }
        source.runtimeRevision &+= 1;target.runtimeRevision &+= 1
        target.select(id);source.state.repair();if let next=source.state.selectedTabID {source.select(next)}
        scheduleSave()
    }
    func scheduleSave() {
        saveTask?.cancel();saveTask=Task {try? await Task.sleep(for:.milliseconds(350));guard !Task.isCancelled else{return};saveNow()}
    }
    @discardableResult func saveNow()->Bool {
        do {
            var history:[SavedNavigationHistory]=[],historyBytes=0
            func appendHistory(_ record:SavedNavigationHistory) {
                guard history.count<128,historyBytes+record.state.count<=16*1024*1024 else{return}
                history.append(record);historyBytes+=record.state.count
            }
            if restoresNavigation {
                for controller in windows where !controller.session.state.isPrivate {
                    let session=controller.session
                    for tab in session.state.tabs {
                        if let runtime=session.runtimes[tab.id] {
                            if let record=runtime.savedNavigation(engine:Self.navigationEngine) {appendHistory(record)}
                            else if runtime.loadedWebView==nil,let record=restoredNavigation[tab.id],record.windowID==session.state.id,record.url==tab.url {appendHistory(record)}
                        } else if let record=restoredNavigation[tab.id],record.windowID==session.state.id,record.url==tab.url {appendHistory(record)}
                    }
                }
            }
            try PrivateFileStore.write(SavedSession(windows:windows.map{$0.session.state},navigationHistory:history).encoded(),to:root.appendingPathComponent("session.json"))
            if restorationError?.hasPrefix("Session could not be saved:")==true {restorationError=nil}
            return true
        }
        catch {restorationError="Session could not be saved: \(error.localizedDescription)";return false}
    }
}
