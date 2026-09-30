import Foundation

extension BrowserWindowState {
    public var activeGlance:BrowserTab? {selectedTab.flatMap{$0.glanceParentID == nil ? nil : $0}}
    public var sidebarSelectedTabID:UUID? {activeGlance?.glanceParentID ?? selectedTabID}
    public func adjacentVisibleTab(_ offset:Int)->UUID? {
        let visible=visibleTabs
        guard !visible.isEmpty,let index=visible.firstIndex(where:{$0.id==sidebarSelectedTabID}) else{return nil}
        return visible[(index+offset%visible.count+visible.count)%visible.count].id
    }
    public func glance(for parent:UUID)->BrowserTab? {tabs.first{$0.glanceParentID==parent}}
    /// Zen's optional automatic preview applies to new external-host tabs from
    /// pinned/essential owners. Existing previews and ordinary links stay intact.
    public func shouldPreviewNewTab(_ target:URL,from parent:UUID,enabled:Bool)->Bool {
        guard enabled,["http","https"].contains(target.scheme?.lowercased() ?? ""),
              let targetHost=target.host?.lowercased(),!targetHost.isEmpty,
              let owner=visibleTabs.first(where:{$0.id==parent}),owner.kind != .regular,
              glance(for:parent)==nil else{return false}
        return URL(string:owner.url)?.host?.lowercased() != targetHost
    }
    /// Children precede their owner so native adapters can close both safely.
    public func closingTabIDs(_ id:UUID)->[UUID] {
        guard tabs.contains(where:{$0.id==id}) else{return []}
        return tabs.filter{$0.glanceParentID==id}.map(\.id)+[id]
    }
    @discardableResult public mutating func openGlance(url:String,from parent:UUID)->UUID? {
        guard let owner=visibleTabs.first(where:{$0.id==parent}),glance(for:parent)==nil else{return nil}
        var preview=BrowserTab(workspaceID:owner.workspaceID,url:url)
        preview.glanceParentID=parent
        tabs.append(preview);clearSplit();selectedTabID=preview.id
        return preview.id
    }
    public mutating func expandGlance(_ id:UUID) {
        guard let i=tabs.firstIndex(where:{$0.id==id}),tabs[i].glanceParentID != nil else{return}
        tabs[i].glanceParentID=nil;tabs[i].workspaceID=activeWorkspaceID
    }
    public mutating func splitGlance(_ id:UUID) {
        guard let parent=tabs.first(where:{$0.id==id})?.glanceParentID else{return}
        expandGlance(id);_ = setSplitTabs([parent,id]);selectedTabID=id
    }
    mutating func repairGlances() {
        var owners=Set<UUID>()
        for i in tabs.indices {
            guard let parent=tabs[i].glanceParentID else{continue}
            if parent==tabs[i].id || !tabs.contains(where:{$0.id==parent && $0.glanceParentID==nil}) || !owners.insert(parent).inserted {
                tabs[i].glanceParentID=nil
            } else if let owner=tabs.first(where:{$0.id==parent}) {tabs[i].workspaceID=owner.workspaceID}
        }
    }
}
