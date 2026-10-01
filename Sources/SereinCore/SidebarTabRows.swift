import Foundation

public struct SidebarTabRow:Identifiable,Equatable,Sendable {
    public let id:UUID
    public let tabIDs:[UUID]
    init(_ ids:[UUID]) {precondition(!ids.isEmpty);id=ids[0];tabIDs=ids}
}
public struct PinnedSidebarDisplayRow:Identifiable,Equatable,Sendable {
    public let id:UUID
    public let depth:Int
    public let isFolder:Bool
    public let tabIDs:[UUID]
}
extension BrowserWindowState {
    /// Join only complete, contiguous groups within one visible folder level.
    /// Collapsed folders retain their existing selected-child representation.
    public var pinnedSidebarDisplayRows:[PinnedSidebarDisplayRow] {
        let rows=pinnedSidebarRows
        var starts:[Int:Int]=[:]
        if sidebar != .collapsed {
            for group in splitGroups where group.workspaceID==activeWorkspaceID {
                let members=Set(group.tabIDs)
                let indices=rows.indices.filter{!rows[$0].isFolder && members.contains(rows[$0].id)}
                guard indices.count==members.count,let first=indices.first,let last=indices.last,
                      last-first+1==indices.count,indices.allSatisfy({rows[$0].depth==rows[first].depth}) else{continue}
                let parents=Set(group.tabIDs.compactMap{id in tabs.first{$0.id==id}}.map(\.folderID))
                if parents.count==1 {starts[first]=last}
            }
        }
        var result:[PinnedSidebarDisplayRow]=[],index=0
        while index<rows.count {
            let row=rows[index],end=starts[index] ?? index
            result.append(.init(id:row.id,depth:row.depth,isFolder:row.isFolder,tabIDs:row.isFolder ? [] : rows[index...end].map(\.id)))
            index=end+1
        }
        return result
    }

    /// Keyboard traversal follows rendered rows, respecting collapsed folders,
    /// and stops at the ends instead of wrapping through hidden tabs.
    public func sidebarNeighbor(of id:UUID,direction:Int)->UUID? {
        let order=sidebarTabIDs
        guard [-1,1].contains(direction),let index=order.firstIndex(of:id) else{return nil}
        return order[min(order.count-1,max(0,index+direction))]
    }

    /// Preserve tab/API order. Mixed-category or separated split members remain
    /// individual rows. Inactive groups remain joined and can be selected again.
    public var regularSidebarRows:[SidebarTabRow] {
        let regular=visibleTabs.filter{$0.kind == .regular}.map(\.id)
        guard sidebar != .collapsed else{return regular.map{SidebarTabRow([$0])}}
        var starts:[Int:Int]=[:]
        for group in splitGroups where group.workspaceID==activeWorkspaceID {
            let split=Set(group.tabIDs),indices=regular.indices.filter{split.contains(regular[$0])}
            if split.count>=2,indices.count==split.count,let first=indices.first,let last=indices.last,last-first+1==indices.count {starts[first]=last}
        }
        var rows:[SidebarTabRow]=[],index=0
        while index<regular.count {
            let end=starts[index] ?? index
            rows.append(SidebarTabRow(Array(regular[index...end])));index=end+1
        }
        return rows
    }
}
