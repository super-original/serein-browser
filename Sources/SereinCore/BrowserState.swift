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
    public var folderID: UUID?
    public var openerTabID: UUID?
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
    // Root, left-column and right-column divider proportions; legacy sessions default to halves.
    public var splitFractions:[Double]?
    public var sidebar: SidebarMode = .expanded
    public var sidebarWidth: Double = 230
    public var closedTabs: [BrowserTab] = []
    public var windowFrame:[Double]?
    // Optional to decode sessions created before folder support.
    public var folders:[TabFolder]?
    public var pinnedOrder:[UUID]?
    public init(isPrivate: Bool = false) {
        self.isPrivate=isPrivate
        let space=Workspace();workspaces=[space];activeWorkspaceID=space.id
        let tab=BrowserTab(workspaceID:space.id);tabs=[tab];selectedTabID=tab.id
    }
    public var selectedTab: BrowserTab? { tabs.first { $0.id == selectedTabID } }
    public var visibleTabs: [BrowserTab] {
        let relevant=tabs.filter { $0.glanceParentID == nil && ($0.kind == .essential || $0.workspaceID == activeWorkspaceID) }
        return relevant.filter{$0.kind == .essential} + orderedPinnedTabs + relevant.filter{$0.kind == .regular}
    }
    @discardableResult public mutating func newTab(url: String = "about:blank", select: Bool = true,kind:TabKind = .regular,index:Int?=nil,opener:UUID?=nil) -> UUID {
        var tab=BrowserTab(workspaceID:activeWorkspaceID,url:url,kind:kind)
        tab.openerTabID=opener.flatMap{parent in tabs.contains{$0.id==parent} ? parent : nil}
        let insertion=index.map{min(tabs.count,max(0,$0))} ?? tabs.count
        tabs.insert(tab,at:insertion)
        if select { selectedTabID=tab.id;clearSplit() }
        return tab.id
    }
    @discardableResult public mutating func setOpener(_ id:UUID,to parent:UUID?)->Bool {
        guard let index=tabs.firstIndex(where:{$0.id==id}) else{return false}
        if let parent {guard parent != id,tabs.contains(where:{$0.id==parent}) else{return false}}
        tabs[index].openerTabID=parent;return true
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
        let previews=tabs.filter{$0.glanceParentID==id}
        for child in previews.map(\.id) {close(child,remember:false)}
        guard let index=tabs.firstIndex(where:{$0.id==id}) else{return}
        let parent=tabs[index].glanceParentID
        let oldOrder=visibleTabs.map(\.id);let selectedIndex=oldOrder.firstIndex(of:id) ?? 0
        let removed=tabs.remove(at:index);forgetPinnedPosition(id)
        for i in tabs.indices where tabs[i].openerTabID==id {tabs[i].openerTabID=nil}
        if remember {var closed=removed;closed.glanceParentID=nil;closedTabs.append(contentsOf:previews);closedTabs.append(closed);closedTabs=Array(closedTabs.suffix(25))}
        removeSplitTab(id)
        if selectedTabID==id {
            let candidates=visibleTabs
            selectedTabID=parent.flatMap{p in candidates.first{$0.id==p}?.id} ?? (candidates.isEmpty ? nil : candidates[min(selectedIndex,candidates.count-1)].id)
        }
        if visibleTabs.isEmpty {newTab()}
    }
    @discardableResult public mutating func reopen() -> UUID? {
        guard var tab=closedTabs.popLast() else{return nil}
        let previousID=tab.id
        let preview=closedTabs.last?.glanceParentID==previousID ? closedTabs.popLast() : nil
        if !workspaces.contains(where:{$0.id==tab.workspaceID}) {tab.workspaceID=activeWorkspaceID}
        if tabs.contains(where:{$0.id==tab.id}) {tab.id=UUID()};tab.glanceParentID=nil
        if let folderID=tab.folderID,folder(folderID)?.workspaceID != tab.workspaceID {tab.folderID=nil}
        if let opener=tab.openerTabID,!tabs.contains(where:{$0.id==opener}) {tab.openerTabID=nil}
        tabs.append(tab)
        if var child=preview {
            if tabs.contains(where:{$0.id==child.id}) {child.id=UUID()}
            child.workspaceID=tab.workspaceID;child.glanceParentID=tab.id
            if child.openerTabID==previousID {child.openerTabID=tab.id}
            tabs.append(child)
        }
        select(tab.id);return tab.id
    }
    @discardableResult public mutating func duplicate(_ id: UUID) -> UUID? {
        guard let old=tabs.first(where:{$0.id==id}) else{return nil}
        let new=BrowserTab(workspaceID:old.workspaceID,url:old.url,title:old.title)
        tabs.append(new);select(new.id);return new.id
    }
    public mutating func setKind(_ id: UUID, _ kind: TabKind) {
        guard let i=tabs.firstIndex(where:{$0.id==id}) else{return}
        if kind != .pinned || tabs[i].folderID.flatMap({folder($0)?.workspaceID}).map({$0 != activeWorkspaceID})==true {forgetPinnedPosition(id);tabs[i].folderID=nil}
        tabs[i].glanceParentID=nil;tabs[i].kind=kind;tabs[i].workspaceID=activeWorkspaceID
        for child in tabs.indices where tabs[child].glanceParentID==id {tabs[child].workspaceID=activeWorkspaceID}
        tabs[i].homeURL=kind == .regular ? nil : tabs[i].url
    }
    public mutating func move(_ id: UUID, before target: UUID) {
        guard id != target, let a=tabs.firstIndex(where:{$0.id==id}),let b=tabs.firstIndex(where:{$0.id==target}),tabs[a].kind==tabs[b].kind else{return}
        if tabs[a].kind == .pinned {
            guard tabs[a].workspaceID==tabs[b].workspaceID else{return}
            reorderPinnedTab(id,before:target)
        }
        let tab=tabs.remove(at:a)
        if let insertion=tabs.firstIndex(where:{$0.id==target}) {tabs.insert(tab,at:insertion)}
    }
    public mutating func moveToWorkspace(_ id: UUID, _ space: UUID) {
        guard workspaces.contains(where:{$0.id==space}),let i=tabs.firstIndex(where:{$0.id==id}) else{return}
        guard tabs[i].workspaceID != space || tabs[i].kind == .essential else{return}
        let wasSelected=sidebarSelectedTabID==id || selectedTabID==id
        forgetPinnedPosition(id)
        tabs[i].glanceParentID=nil;tabs[i].folderID=nil;tabs[i].workspaceID=space
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
        for index in (folders ?? []).indices where folders?[index].workspaceID==id {folders?[index].workspaceID=destination}
        workspaces.removeAll{$0.id==id};if activeWorkspaceID==id {switchWorkspace(destination)}
    }
    public var splitTabIDs:[UUID] {
        guard let primarySplitTabID,let secondaryTabID else{return []}
        return [primarySplitTabID,secondaryTabID]+(additionalSplitTabIDs ?? [])
    }
    public mutating func clearSplit() {
        primarySplitTabID=nil;secondaryTabID=nil;additionalSplitTabIDs=nil;splitFractions=nil
    }
    @discardableResult public mutating func setSplitTabs(_ ids:[UUID]) -> Bool {
        guard (2...4).contains(ids.count),Set(ids).count==ids.count,
              ids.allSatisfy({id in visibleTabs.contains{$0.id==id}}) else{return false}
        if splitTabIDs != ids {splitFractions=nil}
        primarySplitTabID=ids[0];secondaryTabID=ids[1]
        additionalSplitTabIDs=ids.count>2 ? Array(ids.dropFirst(2)) : nil
        if !ids.contains(where:{$0==selectedTabID}) {selectedTabID=ids[0]}
        return true
    }
    public func splitFraction(at index:Int)->Double {
        guard let values=splitFractions,values.indices.contains(index),values[index].isFinite else{return 0.5}
        return min(0.9,max(0.1,values[index]))
    }
    public mutating func setSplitFraction(_ value:Double,at index:Int) {
        guard (0..<3).contains(index),splitTabIDs.count>=2,value.isFinite else{return}
        var values=(0..<3).map{splitFraction(at:$0)};values[index]=min(0.9,max(0.1,value));splitFractions=values
    }
    private mutating func removeSplitTab(_ id:UUID) {
        let ids=splitTabIDs
        guard ids.contains(id) else{return}
        let remaining=ids.filter{$0 != id}
        if remaining.count<2 {clearSplit()} else {_=setSplitTabs(remaining)}
    }
    public mutating func split(with id: UUID) {
        guard let selectedTabID,id != selectedTabID,visibleTabs.contains(where:{$0.id==id}) else{return}
        if let preview=activeGlance {expandGlance(preview.id)}
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
        let knownTabs=Set(tabs.map(\.id))
        for i in tabs.indices {
            if let opener=tabs[i].openerTabID,opener==tabs[i].id || !knownTabs.contains(opener) {tabs[i].openerTabID=nil}
        }
        repairGlances();repairFolders()
        if splitFractions != nil {splitFractions=(0..<3).map{splitFraction(at:$0)}}
        sidebarWidth=min(500,max(180,sidebarWidth.isFinite ? sidebarWidth : 240))
        if !visibleTabs.contains(where:{$0.id==sidebarSelectedTabID}) {selectedTabID=visibleTabs.first?.id}
        if selectedTabID==nil {newTab()}
        var splitSeen=Set<UUID>()
        let panes=Array(splitTabIDs.filter{id in visibleTabs.contains{$0.id==id} && splitSeen.insert(id).inserted}.prefix(4))
        if !panes.contains(where:{$0==selectedTabID}) || !setSplitTabs(panes) {clearSplit()}
    }
}
