import AppKit
import WebKit
import Observation
import SereinCore

@MainActor @Observable final class BrowserSession {
    var state: BrowserWindowState { didSet {manager?.scheduleSave()} }
    var address = ""
    var addressFocused=false
    var findVisible=false
    var findText=""
    var findResult=""
    var libraryPanel: LibraryPanel?
    var compactRevealed=false
    var error: String?
    @ObservationIgnored weak var manager: BrowserManager?
    @ObservationIgnored weak var window: NSWindow?
    @ObservationIgnored var runtimes: [UUID:TabRuntime] = [:]
    @ObservationIgnored var extensionWindow: ExtensionWindow?
    @ObservationIgnored var extensionTabs: [UUID:ExtensionTab] = [:]
    @ObservationIgnored let dataStore: WKWebsiteDataStore
    init(state: BrowserWindowState, manager: BrowserManager) {
        self.state=state;self.manager=manager
        dataStore=state.isPrivate ? .nonPersistent() : .default()
        address=state.selectedTab?.url == "about:blank" ? "" : state.selectedTab?.url ?? ""
    }
    var current: TabRuntime? {state.selectedTabID.map {runtime($0)}}
    var extensions: ExtensionHost? {state.isPrivate ? nil : manager?.extensions}
    func runtime(_ id: UUID) -> TabRuntime {
        if let existing=runtimes[id] {return existing}
        let runtime=TabRuntime(id:id,session:self);runtimes[id]=runtime
        return runtime
    }
    func bridge(_ id: UUID) -> ExtensionTab {
        if let tab=extensionTabs[id] {return tab}
        let tab=ExtensionTab(id:id,session:self);extensionTabs[id]=tab;return tab
    }
    func select(_ id: UUID) {
        let previous=state.selectedTabID.map {bridge($0)}
        state.select(id);address=state.selectedTab?.url ?? "";addressFocused=false
        if address=="about:blank" {address=""}
        _=runtime(id).webView
        extensions?.controller.didActivateTab(bridge(id),previousActiveTab:previous)
    }
    @discardableResult func newTab(url: String = "about:blank", select: Bool = true, configuration: WKWebViewConfiguration? = nil) -> UUID {
        let previous=state.selectedTabID.map{bridge($0)}
        let id=state.newTab(url:url,select:select)
        if let configuration {runtimes[id]=TabRuntime(id:id,session:self,configuration:configuration)}
        extensions?.controller.didOpenTab(bridge(id))
        if select {
            address=url=="about:blank" ? "" : url
            addressFocused=url=="about:blank"
            _=runtime(id).webView
            extensions?.controller.didActivateTab(bridge(id),previousActiveTab:previous)
        }
        return id
    }
    func close(_ id: UUID, ask: Bool = true) {
        if ask,let runtime=runtimes[id],runtime.hasUserEdits {
            confirm("Close this tab?",detail:"This page has been edited. Unsaved changes may be lost.") { [weak self] allowed in if allowed {self?.close(id,ask:false)} }
            return
        }
        let tab=bridge(id);let previous=state.selectedTabID
        extensions?.controller.didCloseTab(tab,windowIsClosing:false)
        runtimes[id]?.dispose();runtimes[id]=nil;extensionTabs[id]=nil
        let before=Set(state.tabs.map(\.id));state.close(id)
        for added in state.tabs where !before.contains(added.id) {extensions?.controller.didOpenTab(bridge(added.id))}
        if previous != state.selectedTabID,let next=state.selectedTabID {select(next)}
    }
    func reopen() {if let id=state.reopen() {extensions?.controller.didOpenTab(bridge(id));select(id)}}
    func duplicate(_ id: UUID) {if let new=state.duplicate(id) {extensions?.controller.didOpenTab(bridge(new));select(new)}}
    func navigate(_ input: String,ask:Bool = true) {
        if ask,current?.hasUserEdits==true {confirm("Leave this page?",detail:"Unsaved changes may be lost.",yes:"Leave"){[weak self] allowed in if allowed{self?.navigate(input,ask:false)}};return}
        guard let url=AddressResolver.resolve(input),let runtime=current else{return}
        address=url.absoluteString;addressFocused=false;runtime.load(url)
    }
    func setKind(_ id: UUID, _ kind: TabKind) {
        state.setKind(id,kind);extensions?.controller.didChangeTabProperties(.pinned,for:bridge(id))
    }
    func move(_ id: UUID, before other: UUID) {
        guard let old=state.tabs.firstIndex(where:{$0.id==id}) else{return}
        state.move(id,before:other);extensions?.controller.didMoveTab(bridge(id),from:old,in:extensionWindow)
    }
    func switchWorkspace(_ id: UUID) {state.switchWorkspace(id);if let tab=state.selectedTabID {select(tab)}}
    func find(backwards: Bool = false) {
        let config=WKFindConfiguration();config.backwards=backwards;config.wraps=true
        current?.webView.find(findText,configuration:config) {[weak self] result in self?.findResult=result.matchFound ? "" : "No matches"}
    }
    func update(_ id: UUID, url: String?, title: String?) {
        guard let i=state.tabs.firstIndex(where:{$0.id==id}) else{return}
        if let url {state.tabs[i].url=url}
        if let title,!title.isEmpty {state.tabs[i].title=title}
        if state.selectedTabID==id,!addressFocused {address=state.tabs[i].url=="about:blank" ? "" : state.tabs[i].url}
        extensions?.controller.didChangeTabProperties([.URL,.title,.loading],for:bridge(id))
    }
    func bookmark() {
        guard let tab=state.selectedTab else{return}
        manager?.library.bookmark(title:tab.title,url:tab.url)
    }
    func confirm(_ title: String, detail: String, yes: String = "Continue", completion: @escaping @MainActor (Bool)->Void) {
        let alert=NSAlert();alert.messageText=title;alert.informativeText=detail;alert.addButton(withTitle:yes);alert.addButton(withTitle:"Cancel")
        if let window {alert.beginSheetModal(for:window){r in completion(r == .alertFirstButtonReturn)}}
        else {completion(false)}
    }
    func unload(_ id: UUID) {
        guard id != state.selectedTabID,id != state.secondaryTabID else{return}
        confirm("Unload this tab?",detail:"The page will reload when selected. Media will stop and unsaved page state will be lost.",yes:"Unload") { [weak self] yes in
            guard yes,let self else{return};self.runtimes[id]?.dispose();self.runtimes[id]=nil
        }
    }
}
enum LibraryPanel: String, Identifiable {case bookmarks,history,downloads,extensions,settings;var id:String{rawValue}}
