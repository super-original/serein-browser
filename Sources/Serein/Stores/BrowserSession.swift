import AppKit
import WebKit
import Observation
import SereinCore

@MainActor @Observable final class BrowserSession {
    var state: BrowserWindowState { didSet {manager?.scheduleSave()} }
    var tabSelection=TabSelection()
    var address = ""
    var addressFocused=false
    var findVisible=false
    var findText=""
    var findResult=""
    @ObservationIgnored var findRequestID=UUID()
    var libraryPanel: LibraryPanel?
    var compactRevealed=false
    var error: String?
    @ObservationIgnored weak var manager: BrowserManager?
    @ObservationIgnored weak var window: NSWindow?
    @ObservationIgnored var runtimes: [UUID:TabRuntime] = [:]
    @ObservationIgnored var extensionWindow: ExtensionWindow?
    @ObservationIgnored var extensionTabs: [UUID:ExtensionTab] = [:]
    @ObservationIgnored var actionAnchors:[UUID:WeakActionAnchor]=[:]
    let sitePermissions: SitePermissionStore
    @ObservationIgnored let dataStore: WKWebsiteDataStore
    init(state: BrowserWindowState, manager: BrowserManager) {
        self.state=state;self.manager=manager
        sitePermissions=state.isPrivate ? SitePermissionStore() : manager.sitePermissions
        dataStore=state.isPrivate ? .nonPersistent() : .default()
        tabSelection.selectOnly(state.selectedTabID)
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
    func publishSelection(previousActive:UUID?,previousHighlighted:Set<UUID>,refreshActive:Bool=true) {
        let valid=Set(state.tabs.map(\.id));tabSelection.retain(valid)
        if previousActive != state.selectedTabID {findRequestID=UUID();findResult=""}
        if refreshActive {address=state.selectedTab?.url == "about:blank" ? "" : state.selectedTab?.url ?? "";addressFocused=false}
        if let id=state.selectedTabID,refreshActive {
            _=runtime(id).webView
            if previousActive != id {extensions?.controller.didActivateTab(bridge(id),previousActiveTab:previousActive.flatMap{valid.contains($0) ? bridge($0) : nil})}
        }
        let removed=previousHighlighted.subtracting(tabSelection.ids).intersection(valid)
        let added=tabSelection.ids.subtracting(previousHighlighted)
        if !removed.isEmpty {extensions?.controller.didDeselectTabs(state.tabs.filter{removed.contains($0.id)}.map{bridge($0.id)})}
        if !added.isEmpty {extensions?.controller.didSelectTabs(state.tabs.filter{added.contains($0.id)}.map{bridge($0.id)})}
        if findVisible,previousActive != state.selectedTabID {find()}
    }
    func select(_ id:UUID,preservingSelection:Bool=false) {
        guard state.tabs.contains(where:{$0.id==id}) else{return}
        let previous=state.selectedTabID,highlighted=tabSelection.ids
        state.select(id)
        if preservingSelection {tabSelection.set(id,selected:true)} else {tabSelection.selectOnly(state.selectedTabID)}
        publishSelection(previousActive:previous,previousHighlighted:highlighted,refreshActive:!preservingSelection || previous != id)
    }
    @discardableResult func setHighlighted(_ id:UUID,_ selected:Bool)->Bool {
        guard state.tabs.contains(where:{$0.id==id}) else{return false}
        let previous=tabSelection.ids
        tabSelection.set(id,selected:selected)
        publishSelection(previousActive:state.selectedTabID,previousHighlighted:previous,refreshActive:false)
        return true
    }
    func clickTab(_ id:UUID,modifiers:NSEvent.ModifierFlags) {
        if !modifiers.intersection([.command,.shift]).isEmpty,let preview=state.activeGlance {state.expandGlance(preview.id)}
        guard state.visibleTabs.contains(where:{$0.id==id}) else{return}
        if modifiers.contains(.shift) {
            let previous=state.selectedTabID,highlighted=tabSelection.ids
            tabSelection.range(to:id,in:state.visibleTabs.map(\.id),additive:modifiers.contains(.command))
            state.select(id);publishSelection(previousActive:previous,previousHighlighted:highlighted)
        } else if modifiers.contains(.command) {
            let previous=tabSelection.ids;tabSelection.toggle(id)
            publishSelection(previousActive:state.selectedTabID,previousHighlighted:previous,refreshActive:false)
        } else {select(id)}
    }
    var closeConsentSnapshot:[UUID:UUID?] {
        Dictionary(uniqueKeysWithValues:state.tabs.map{($0.id,runtimes[$0.id]?.documentID)})
    }
    func splitHighlighted() {
        let ids=state.visibleTabs.filter{tabSelection.ids.contains($0.id)}.map(\.id)
        let previous=state.selectedTabID,highlighted=tabSelection.ids
        if state.setSplitTabs(ids) {publishSelection(previousActive:previous,previousHighlighted:highlighted)}
    }
    func closeHighlighted() {
        let ids=state.tabs.filter{tabSelection.ids.contains($0.id)}.map(\.id)
        guard !ids.isEmpty else{return}
        let group=ids.flatMap{state.closingTabIDs($0)}
        let documents=group.map{(id:$0,document:runtimes[$0]?.documentID)}
        let closeAll: @MainActor ()->Void = { [weak self] in
            guard let self,ids.flatMap({self.state.closingTabIDs($0)})==group,documents.allSatisfy({target in self.state.tabs.contains{$0.id==target.id} && self.runtimes[target.id]?.documentID==target.document}) else{return}
            for id in ids {self.close(id,ask:false)}
        }
        if group.contains(where:{runtimes[$0]?.hasUserEdits == true}) {
            confirm("Close \(ids.count) selected tabs?",detail:"Edited pages may contain unsaved changes.",yes:"Close Tabs"){if $0 {closeAll()}}
        } else {closeAll()}
    }
    @discardableResult func newTab(url:String="about:blank",select:Bool=true,configuration:WKWebViewConfiguration?=nil)->UUID {
        let previous=state.selectedTabID,highlighted=tabSelection.ids
        let id=state.newTab(url:url,select:select)
        if let configuration {runtimes[id]=TabRuntime(id:id,session:self,configuration:configuration)}
        extensions?.controller.didOpenTab(bridge(id))
        if select {
            tabSelection.selectOnly(id);publishSelection(previousActive:previous,previousHighlighted:highlighted)
            addressFocused=url=="about:blank"
        }
        return id
    }
    func close(_ id:UUID,ask:Bool=true,completion:(@MainActor (Bool)->Void)?=nil) {
        guard state.tabs.contains(where:{$0.id==id}) else{completion?(false);return}
        let group=state.closingTabIDs(id)
        if ask,group.contains(where:{runtimes[$0]?.hasUserEdits==true}) {
            let documents=group.map{(id:$0,document:runtimes[$0]?.documentID)}
            confirm("Close this tab?",detail:"This tab or its preview has edits. Unsaved changes may be lost.",yes:"Close Tab"){[weak self] allowed in
                guard allowed,let self,self.state.closingTabIDs(id)==group,
                      documents.allSatisfy({self.runtimes[$0.id]?.documentID==$0.document}) else{completion?(false);return}
                self.close(id,ask:false,completion:completion)
            }
            return
        }
        for child in group where child != id {close(child,ask:false)}
        let previous=state.selectedTabID,highlighted=tabSelection.ids
        extensions?.controller.didCloseTab(bridge(id),windowIsClosing:false)
        runtimes[id]?.dispose();runtimes[id]=nil;extensionTabs[id]=nil
        let before=Set(state.tabs.map(\.id));state.close(id)
        for added in state.tabs where !before.contains(added.id) {extensions?.controller.didOpenTab(bridge(added.id))}
        tabSelection.retain(Set(state.tabs.map(\.id)))
        if previous==id || tabSelection.ids.isEmpty {tabSelection.selectOnly(state.selectedTabID)}
        publishSelection(previousActive:previous,previousHighlighted:highlighted,refreshActive:previous != state.selectedTabID)
        completion?(true)
    }
    func reopen() {
        let previous=state.selectedTabID,highlighted=tabSelection.ids
        if let id=state.reopen() {extensions?.controller.didOpenTab(bridge(id));tabSelection.selectOnly(id);publishSelection(previousActive:previous,previousHighlighted:highlighted)}
    }
    func duplicate(_ id:UUID) {
        let previous=state.selectedTabID,highlighted=tabSelection.ids
        if let new=state.duplicate(id) {extensions?.controller.didOpenTab(bridge(new));tabSelection.selectOnly(new);publishSelection(previousActive:previous,previousHighlighted:highlighted)}
    }
    func navigate(_ input: String,ask:Bool = true) {
        if ask,let runtime=current,runtime.hasUserEdits {
            let tabID=runtime.id,documentID=runtime.documentID
            confirm("Leave this page?",detail:"Unsaved changes may be lost.",yes:"Leave") { [weak self,weak runtime] allowed in
                guard allowed,let self,let runtime,self.state.selectedTabID==tabID,
                      self.runtimes[tabID] === runtime,runtime.documentID==documentID else{return}
                self.navigate(input,ask:false)
            }
            return
        }
        let entered=URL(string:input.trimmingCharacters(in:.whitespacesAndNewlines))
        if entered?.scheme?.lowercased()=="webkit-extension",entered.flatMap({extensions?.controller.extensionContext(for:$0)})==nil {
            error="This extension page is unavailable in this window.";return
        }
        let target=entered.flatMap{extensions?.controller.extensionContext(for:$0)} != nil ? entered : AddressResolver.resolve(input)
        guard let url=target,let runtime=current else{return}
        address=url.absoluteString;addressFocused=false;runtime.load(url)
    }
    func setKind(_ id: UUID, _ kind: TabKind) {
        state.setKind(id,kind);extensions?.controller.didChangeTabProperties(.pinned,for:bridge(id))
    }
    func setHighlightedKind(_ kind:TabKind) {
        let targets=state.visibleTabs.filter{tabSelection.ids.contains($0.id) && $0.kind != kind}.map(\.id)
        for id in targets {setKind(id,kind)}
    }
    func moveHighlightedToWorkspace(_ workspace:UUID) {
        guard state.workspaces.contains(where:{$0.id==workspace}) else{return}
        let targets=state.visibleTabs.filter{tabSelection.ids.contains($0.id) && ($0.workspaceID != workspace || $0.kind == .essential)}.map(\.id)
        guard !targets.isEmpty else{return}
        // Snapshot selection before the first move changes the active tab.
        changeWorkspace {state in for id in targets {state.moveToWorkspace(id,workspace)}}
    }
    func move(_ id: UUID, before other: UUID) {
        guard let old=state.tabs.firstIndex(where:{$0.id==id}) else{return}
        state.move(id,before:other);extensions?.controller.didMoveTab(bridge(id),from:old,in:extensionWindow)
    }
    private func changeWorkspace(_ change:(inout BrowserWindowState)->Void) {
        let previous=state.selectedTabID,highlighted=tabSelection.ids
        let oldTabs=Set(state.tabs.map(\.id))
        change(&state)
        for tab in state.tabs where !oldTabs.contains(tab.id) {extensions?.controller.didOpenTab(bridge(tab.id))}
        tabSelection.selectOnly(state.selectedTabID)
        publishSelection(previousActive:previous,previousHighlighted:highlighted)
    }
    func switchWorkspace(_ id: UUID) {changeWorkspace{$0.switchWorkspace(id)}}
    @discardableResult func addWorkspace(name: String) -> UUID {
        var id:UUID!
        changeWorkspace{id=$0.addWorkspace(name:name)}
        return id
    }
    func removeWorkspace(_ id: UUID) {changeWorkspace{$0.removeWorkspace(id)}}
    func moveTabToWorkspace(_ id: UUID,_ workspace: UUID) {changeWorkspace{$0.moveToWorkspace(id,workspace)}}
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
    // Library panels are sheets. Their dialogs must be attached to that sheet,
    // otherwise AppKit queues them behind the library until it is dismissed.
    var dialogWindow: NSWindow? {
        if libraryPanel != nil,let sheet=window?.attachedSheet {return sheet}
        return window
    }
    func confirm(_ title: String, detail: String, yes: String = "Continue", completion: @escaping @MainActor (Bool)->Void) {
        let alert=NSAlert();alert.messageText=title;alert.informativeText=detail;alert.addButton(withTitle:yes);alert.addButton(withTitle:"Cancel")
        if let window=dialogWindow {alert.beginSheetModal(for:window){r in completion(r == .alertFirstButtonReturn)}}
        else {completion(false)}
    }
    func canUnload(_ id: UUID) -> Bool {
        state.tabs.contains{$0.id==id} && runtimes[id]?.loadedWebView != nil && id != state.selectedTabID && id != state.activeGlance?.glanceParentID && !state.splitTabIDs.contains(id)
    }
    func unload(_ id: UUID) {
        guard canUnload(id),let runtime=runtimes[id] else{return}
        let document=runtime.documentID
        confirm("Unload this tab?",detail:"The page will reload when selected. Media will stop and unsaved page state will be lost.",yes:"Unload") { [weak self,weak runtime] yes in
            guard yes,let self,let runtime,self.canUnload(id),self.runtimes[id] === runtime,runtime.documentID==document else{return};runtime.dispose();self.runtimes[id]=nil
        }
    }
}
enum LibraryPanel: String, Identifiable {case bookmarks,history,downloads,extensions,settings;var id:String{rawValue}}
