import Foundation

public enum SidebarMode: String, Codable, CaseIterable, Sendable { case expanded, collapsed, compact }
public enum TabKind: String, Codable, Sendable { case regular, pinned, essential }
public struct BrowserTab: Identifiable, Codable, Equatable, Sendable {
    public var id: UUID
    public var workspaceID: UUID
    public var url: String
    public var title: String
    public var kind: TabKind
    public var homeURL: String?
    public var glanceParentID: UUID?
    public init(id: UUID = UUID(), workspaceID: UUID, url: String = "about:blank", title: String = "New Tab", kind: TabKind = .regular) {
        self.id=id; self.workspaceID=workspaceID; self.url=url; self.title=title; self.kind=kind
        homeURL = kind == .regular ? nil : url
    }
}
public struct Workspace: Identifiable, Codable, Equatable, Sendable {
    public var id: UUID
    public var name: String
    public var symbol: String
    public init(id: UUID = UUID(), name: String = "Personal", symbol: String = "circle") { self.id=id;self.name=name;self.symbol=symbol }
}
public struct BrowserWindowState: Identifiable, Codable, Equatable, Sendable {
    public var id = UUID()
    public var isPrivate: Bool
    public var workspaces: [Workspace]
    public var activeWorkspaceID: UUID
    public var tabs: [BrowserTab]
    public var selectedTabID: UUID?
    public var secondaryTabID: UUID?
    public var primarySplitTabID: UUID?
    // Optional for decoding sessions written before multi-pane support.
    public var additionalSplitTabIDs: [UUID]?
    public var sidebar: SidebarMode = .expanded
    public var sidebarWidth: Double = 230
    public var closedTabs: [BrowserTab] = []
    public var windowFrame:[Double]?
    public init(isPrivate: Bool = false) {
        self.isPrivate=isPrivate
        let space=Workspace();workspaces=[space];activeWorkspaceID=space.id
        let tab=BrowserTab(workspaceID:space.id);tabs=[tab];selectedTabID=tab.id
    }
    public var selectedTab: BrowserTab? { tabs.first { $0.id == selectedTabID } }
    public var visibleTabs: [BrowserTab] {
        let relevant=tabs.filter { $0.glanceParentID == nil && ($0.kind == .essential || $0.workspaceID == activeWorkspaceID) }
        return relevant.filter{$0.kind == .essential} + relevant.filter{$0.kind == .pinned} + relevant.filter{$0.kind == .regular}
    }
    @discardableResult public mutating func newTab(url: String = "about:blank", select: Bool = true) -> UUID {
        let tab=BrowserTab(workspaceID:activeWorkspaceID,url:url);tabs.append(tab)
        if select { selectedTabID=tab.id;clearSplit() }
        return tab.id
    }
    public mutating func select(_ id: UUID) {
        guard let requested=tabs.first(where:{$0.id==id}) else{return}
        let owner=requested.glanceParentID.flatMap{parent in tabs.first{$0.id==parent}} ?? requested
        if owner.kind != .essential && owner.workspaceID != activeWorkspaceID {activeWorkspaceID=owner.workspaceID;clearSplit()}
        let target=glance(for:owner.id)?.id ?? requested.id
        if !splitTabIDs.isEmpty,!splitTabIDs.contains(target) {clearSplit()}
        selectedTabID=target
    }
    public mutating func close(_ id: UUID, remember: Bool = true) {
        guard tabs.contains(where:{$0.id==id}) else{return}
        for child in tabs.filter({$0.glanceParentID==id}).map(\.id) {close(child,remember:false)}
        guard let index=tabs.firstIndex(where:{$0.id==id}) else{return}
        let parent=tabs[index].glanceParentID
        let oldOrder=visibleTabs.map(\.id);let selectedIndex=oldOrder.firstIndex(of:id) ?? 0
        let removed=tabs.remove(at:index)
        if remember {var closed=removed;closed.glanceParentID=nil;closedTabs.append(closed);closedTabs=Array(closedTabs.suffix(25))}
        removeSplitTab(id)
        if selectedTabID==id {
            let candidates=visibleTabs
            selectedTabID=parent.flatMap{p in candidates.first{$0.id==p}?.id} ?? (candidates.isEmpty ? nil : candidates[min(selectedIndex,candidates.count-1)].id)
        }
        if visibleTabs.isEmpty {newTab()}
    }
    @discardableResult public mutating func reopen() -> UUID? {
        guard var tab=closedTabs.popLast() else{return nil}
        if !workspaces.contains(where:{$0.id==tab.workspaceID}) {tab.workspaceID=activeWorkspaceID}
        if tabs.contains(where:{$0.id==tab.id}) {tab.id=UUID()};tab.glanceParentID=nil
        tabs.append(tab);select(tab.id);return tab.id
    }
    @discardableResult public mutating func duplicate(_ id: UUID) -> UUID? {
        guard let old=tabs.first(where:{$0.id==id}) else{return nil}
        let new=BrowserTab(workspaceID:old.workspaceID,url:old.url,title:old.title)
        tabs.append(new);select(new.id);return new.id
    }
    public mutating func setKind(_ id: UUID, _ kind: TabKind) {
        guard let i=tabs.firstIndex(where:{$0.id==id}) else{return}
        tabs[i].glanceParentID=nil;tabs[i].kind=kind;tabs[i].workspaceID=activeWorkspaceID
        for child in tabs.indices where tabs[child].glanceParentID==id {tabs[child].workspaceID=activeWorkspaceID}
        tabs[i].homeURL=kind == .regular ? nil : tabs[i].url
    }
    public mutating func move(_ id: UUID, before target: UUID) {
        guard id != target, let a=tabs.firstIndex(where:{$0.id==id}),let b=tabs.firstIndex(where:{$0.id==target}),tabs[a].kind==tabs[b].kind else{return}
        let tab=tabs.remove(at:a)
        if let insertion=tabs.firstIndex(where:{$0.id==target}) {tabs.insert(tab,at:insertion)}
    }
    public mutating func moveToWorkspace(_ id: UUID, _ space: UUID) {
        guard workspaces.contains(where:{$0.id==space}),let i=tabs.firstIndex(where:{$0.id==id}) else{return}
        let wasSelected=sidebarSelectedTabID==id || selectedTabID==id
        tabs[i].glanceParentID=nil;tabs[i].workspaceID=space
        for child in tabs.indices where tabs[child].glanceParentID==id {tabs[child].workspaceID=space}
        if tabs[i].kind == .essential {tabs[i].kind = .pinned}
        if space != activeWorkspaceID {removeSplitTab(id)}
        if wasSelected {selectedTabID=visibleTabs.first?.id}
        if visibleTabs.isEmpty {newTab()}
    }
    @discardableResult public mutating func addWorkspace(name: String) -> UUID {
        let space=Workspace(name:name.trimmingCharacters(in:.whitespacesAndNewlines).isEmpty ? "Workspace" : name)
        workspaces.append(space);switchWorkspace(space.id);return space.id
    }
    public mutating func switchWorkspace(_ id: UUID) {
        guard workspaces.contains(where:{$0.id==id}) else{return}
        activeWorkspaceID=id;clearSplit()
        selectedTabID=visibleTabs.first(where:{$0.kind != .essential})?.id ?? visibleTabs.first?.id
        if selectedTabID==nil {newTab()}
    }
    public mutating func removeWorkspace(_ id: UUID) {
        guard workspaces.count>1,workspaces.contains(where:{$0.id==id}) else{return}
        let destination=workspaces.first{$0.id != id}!.id
        for i in tabs.indices where tabs[i].workspaceID==id {tabs[i].workspaceID=destination}
        workspaces.removeAll{$0.id==id};if activeWorkspaceID==id {switchWorkspace(destination)}
    }
    public var splitTabIDs:[UUID] {
        guard let primarySplitTabID,let secondaryTabID else{return []}
        return [primarySplitTabID,secondaryTabID]+(additionalSplitTabIDs ?? [])
    }
    public mutating func clearSplit() {
        primarySplitTabID=nil;secondaryTabID=nil;additionalSplitTabIDs=nil
    }
    @discardableResult public mutating func setSplitTabs(_ ids:[UUID]) -> Bool {
        guard (2...4).contains(ids.count),Set(ids).count==ids.count,
              ids.allSatisfy({id in visibleTabs.contains{$0.id==id}}) else{return false}
        primarySplitTabID=ids[0];secondaryTabID=ids[1]
        additionalSplitTabIDs=ids.count>2 ? Array(ids.dropFirst(2)) : nil
        if !ids.contains(where:{$0==selectedTabID}) {selectedTabID=ids[0]}
        return true
    }
    private mutating func removeSplitTab(_ id:UUID) {
        let ids=splitTabIDs
        guard ids.contains(id) else{return}
        let remaining=ids.filter{$0 != id}
        if remaining.count<2 {clearSplit()} else {_=setSplitTabs(remaining)}
    }
    public mutating func split(with id: UUID) {
        if let preview=activeGlance {expandGlance(preview.id)}
        guard let selectedTabID,id != selectedTabID,visibleTabs.contains(where:{$0.id==id}) else{return}
        _=setSplitTabs([selectedTabID,id])
    }
    public mutating func repair() {
        if workspaces.isEmpty {workspaces=[Workspace()]}
        var seen=Set<UUID>();workspaces=workspaces.filter{seen.insert($0.id).inserted}
        if !workspaces.contains(where:{$0.id==activeWorkspaceID}) {activeWorkspaceID=workspaces[0].id}
        seen=[];tabs=tabs.filter{seen.insert($0.id).inserted}
        for i in tabs.indices {
            if !workspaces.contains(where:{$0.id==tabs[i].workspaceID}) {tabs[i].workspaceID=activeWorkspaceID}
        }
        repairGlances()
        sidebarWidth=min(500,max(180,sidebarWidth.isFinite ? sidebarWidth : 240))
        if !visibleTabs.contains(where:{$0.id==sidebarSelectedTabID}) {selectedTabID=visibleTabs.first?.id}
        if selectedTabID==nil {newTab()}
        var splitSeen=Set<UUID>()
        let panes=Array(splitTabIDs.filter{id in visibleTabs.contains{$0.id==id} && splitSeen.insert(id).inserted}.prefix(4))
        if !panes.contains(where:{$0==selectedTabID}) || !setSplitTabs(panes) {clearSplit()}
    }
}
