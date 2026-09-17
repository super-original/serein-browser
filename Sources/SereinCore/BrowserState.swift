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
    public var sidebar: SidebarMode = .expanded
    public var sidebarWidth: Double = 230
    public var closedTabs: [BrowserTab] = []
    public init(isPrivate: Bool = false) {
        self.isPrivate=isPrivate
        let space=Workspace();workspaces=[space];activeWorkspaceID=space.id
        let tab=BrowserTab(workspaceID:space.id);tabs=[tab];selectedTabID=tab.id
    }
    public var selectedTab: BrowserTab? { tabs.first { $0.id == selectedTabID } }
    public var visibleTabs: [BrowserTab] {
        let relevant=tabs.filter { $0.kind == .essential || $0.workspaceID == activeWorkspaceID }
        return relevant.filter{$0.kind == .essential} + relevant.filter{$0.kind == .pinned} + relevant.filter{$0.kind == .regular}
    }
    @discardableResult public mutating func newTab(url: String = "about:blank", select: Bool = true) -> UUID {
        let tab=BrowserTab(workspaceID:activeWorkspaceID,url:url);tabs.append(tab)
        if select { selectedTabID=tab.id }
        return tab.id
    }
    public mutating func select(_ id: UUID) {
        guard let tab=tabs.first(where:{$0.id==id}) else {return}
        if tab.kind != .essential && tab.workspaceID != activeWorkspaceID {activeWorkspaceID=tab.workspaceID;secondaryTabID=nil}
        if secondaryTabID == id {secondaryTabID=selectedTabID}
        selectedTabID=id
    }
    public mutating func close(_ id: UUID, remember: Bool = true) {
        guard let index=tabs.firstIndex(where:{$0.id==id}) else{return}
        let oldOrder=visibleTabs.map(\.id);let selectedIndex=oldOrder.firstIndex(of:id) ?? 0
        let removed=tabs.remove(at:index)
        if remember {closedTabs.append(removed);closedTabs=Array(closedTabs.suffix(25))}
        if secondaryTabID==id {secondaryTabID=nil}
        if selectedTabID==id {
            let candidates=visibleTabs
            selectedTabID=candidates.isEmpty ? nil : candidates[min(selectedIndex,candidates.count-1)].id
        }
        if selectedTabID==secondaryTabID {secondaryTabID=nil}
        if visibleTabs.isEmpty {newTab()}
    }
    @discardableResult public mutating func reopen() -> UUID? {
        guard var tab=closedTabs.popLast() else{return nil}
        if !workspaces.contains(where:{$0.id==tab.workspaceID}) {tab.workspaceID=activeWorkspaceID}
        if tabs.contains(where:{$0.id==tab.id}) {tab.id=UUID()}
        tabs.append(tab);select(tab.id);return tab.id
    }
    @discardableResult public mutating func duplicate(_ id: UUID) -> UUID? {
        guard let old=tabs.first(where:{$0.id==id}) else{return nil}
        let new=BrowserTab(workspaceID:old.workspaceID,url:old.url,title:old.title)
        tabs.append(new);select(new.id);return new.id
    }
    public mutating func setKind(_ id: UUID, _ kind: TabKind) {
        guard let i=tabs.firstIndex(where:{$0.id==id}) else{return}
        tabs[i].kind=kind;tabs[i].workspaceID=activeWorkspaceID
        tabs[i].homeURL=kind == .regular ? nil : tabs[i].url
    }
    public mutating func move(_ id: UUID, before target: UUID) {
        guard id != target, let a=tabs.firstIndex(where:{$0.id==id}),let b=tabs.firstIndex(where:{$0.id==target}),tabs[a].kind==tabs[b].kind else{return}
        let tab=tabs.remove(at:a)
        if let insertion=tabs.firstIndex(where:{$0.id==target}) {tabs.insert(tab,at:insertion)}
    }
    public mutating func moveToWorkspace(_ id: UUID, _ space: UUID) {
        guard workspaces.contains(where:{$0.id==space}),let i=tabs.firstIndex(where:{$0.id==id}) else{return}
        tabs[i].workspaceID=space
        if tabs[i].kind == .essential {tabs[i].kind = .pinned}
        if secondaryTabID==id {secondaryTabID=nil}
        if selectedTabID==id {selectedTabID=visibleTabs.first?.id}
        if visibleTabs.isEmpty {newTab()}
    }
    @discardableResult public mutating func addWorkspace(name: String) -> UUID {
        let space=Workspace(name:name.trimmingCharacters(in:.whitespacesAndNewlines).isEmpty ? "Workspace" : name)
        workspaces.append(space);switchWorkspace(space.id);return space.id
    }
    public mutating func switchWorkspace(_ id: UUID) {
        guard workspaces.contains(where:{$0.id==id}) else{return}
        activeWorkspaceID=id;secondaryTabID=nil
        selectedTabID=visibleTabs.first(where:{$0.kind != .essential})?.id ?? visibleTabs.first?.id
        if selectedTabID==nil {newTab()}
    }
    public mutating func removeWorkspace(_ id: UUID) {
        guard workspaces.count>1,workspaces.contains(where:{$0.id==id}) else{return}
        let destination=workspaces.first{$0.id != id}!.id
        for i in tabs.indices where tabs[i].workspaceID==id {tabs[i].workspaceID=destination}
        workspaces.removeAll{$0.id==id};if activeWorkspaceID==id {switchWorkspace(destination)}
    }
    public mutating func split(with id: UUID) {
        guard id != selectedTabID,visibleTabs.contains(where:{$0.id==id}) else{return}
        secondaryTabID=id
    }
    public mutating func repair() {
        if workspaces.isEmpty {workspaces=[Workspace()]}
        var seen=Set<UUID>();workspaces=workspaces.filter{seen.insert($0.id).inserted}
        if !workspaces.contains(where:{$0.id==activeWorkspaceID}) {activeWorkspaceID=workspaces[0].id}
        seen=[];tabs=tabs.filter{seen.insert($0.id).inserted}
        for i in tabs.indices {
            if !workspaces.contains(where:{$0.id==tabs[i].workspaceID}) {tabs[i].workspaceID=activeWorkspaceID}
        }
        sidebarWidth=min(500,max(180,sidebarWidth.isFinite ? sidebarWidth : 240))
        if !visibleTabs.contains(where:{$0.id==selectedTabID}) {selectedTabID=visibleTabs.first?.id}
        if selectedTabID==nil {newTab()}
        if secondaryTabID==selectedTabID || !visibleTabs.contains(where:{$0.id==secondaryTabID}) {secondaryTabID=nil}
    }
}
