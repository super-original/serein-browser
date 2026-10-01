import Foundation

/// Inactive groups retain composition without keeping their pages on screen.
public struct SavedSplitGroup:Codable,Equatable,Sendable {
    public var workspaceID:UUID
    public var tabIDs:[UUID]
    public var layout:SplitLayout
    public var fractions:[Double]?
}

extension BrowserWindowState {
    /// Explicitly dissolve one group without activating it or touching others.
    @discardableResult public mutating func removeSplitGroup(containing id:UUID)->Bool {
        if splitTabIDs.contains(id) {clearSplit();return true}
        guard let index=inactiveSplitGroups?.firstIndex(where:{$0.tabIDs.contains(id)}) else{return false}
        inactiveSplitGroups?.remove(at:index)
        if inactiveSplitGroups?.isEmpty==true {inactiveSplitGroups=nil}
        return true
    }

    public var splitGroups:[SavedSplitGroup] {
        let active = splitTabIDs.count>=2 ? [SavedSplitGroup(workspaceID:activeWorkspaceID,tabIDs:splitTabIDs,layout:resolvedSplitLayout,fractions:splitFractions)] : []
        return active+(inactiveSplitGroups ?? [])
    }

    mutating func parkSplit() {
        guard splitTabIDs.count>=2 else {clearSplit();return}
        let group=SavedSplitGroup(workspaceID:activeWorkspaceID,tabIDs:splitTabIDs,layout:resolvedSplitLayout,fractions:splitFractions)
        removeInactiveSplitMembers(Set(group.tabIDs))
        inactiveSplitGroups=(inactiveSplitGroups ?? [])+[group]
        clearSplit()
    }

    mutating func restoreSplit(containing id:UUID) {
        guard let index=inactiveSplitGroups?.firstIndex(where:{$0.workspaceID==activeWorkspaceID && $0.tabIDs.contains(id)}) else{return}
        let group=inactiveSplitGroups!.remove(at:index)
        if inactiveSplitGroups?.isEmpty==true {inactiveSplitGroups=nil}
        if setSplitTabs(group.tabIDs) {splitLayout=group.layout;splitFractions=group.fractions}
    }

    mutating func removeInactiveSplitMembers(_ ids:Set<UUID>) {
        inactiveSplitGroups=inactiveSplitGroups?.compactMap {group in
            var result=group
            result.tabIDs.removeAll{ids.contains($0)}
            guard result.tabIDs.count>=2 else{return nil}
            if result.tabIDs != group.tabIDs {result.fractions=nil}
            return result
        }
        if inactiveSplitGroups?.isEmpty==true {inactiveSplitGroups=nil}
    }

    mutating func repairInactiveSplits() {
        var claimed=Set(splitTabIDs)
        inactiveSplitGroups=inactiveSplitGroups?.compactMap {group in
            guard workspaces.contains(where:{$0.id==group.workspaceID}) else{return nil}
            var result=group,seen=Set<UUID>()
            result.tabIDs=Array(group.tabIDs.filter {id in
                !claimed.contains(id) && seen.insert(id).inserted && tabs.contains {
                    $0.id==id && $0.glanceParentID==nil && ($0.kind == .essential || $0.workspaceID==group.workspaceID)
                }
            }.prefix(4))
            guard result.tabIDs.count>=2 else{return nil}
            if result.tabIDs != group.tabIDs {result.fractions=nil}
            result.fractions=result.fractions.map {values in (0..<3).map {index in
                let fallback=result.layout == .grid ? 0.5 : min(1,Double(index+1)/Double(result.tabIDs.count))
                guard values.indices.contains(index),values[index].isFinite else{return fallback}
                return min(1,max(0,values[index]))
            }}
            claimed.formUnion(result.tabIDs)
            return result
        }
        if inactiveSplitGroups?.isEmpty==true {inactiveSplitGroups=nil}
    }
}
