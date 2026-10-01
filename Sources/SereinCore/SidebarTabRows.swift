import Foundation

public struct SidebarTabRow:Identifiable,Equatable,Sendable {
    public let id:UUID
    public let tabIDs:[UUID]
    init(_ ids:[UUID]) {precondition(!ids.isEmpty);id=ids[0];tabIDs=ids}
}
extension BrowserWindowState {
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
