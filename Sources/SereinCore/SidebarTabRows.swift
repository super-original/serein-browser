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
    /// individual rows until persistent general-purpose groups are implemented.
    public var regularSidebarRows:[SidebarTabRow] {
        let regular=visibleTabs.filter{$0.kind == .regular}.map(\.id)
        let split=Set(splitTabIDs),indices=regular.indices.filter{split.contains(regular[$0])}
        guard sidebar != .collapsed,split.count>=2,indices.count==split.count,
              let first=indices.first,let last=indices.last,last-first+1==indices.count else{return regular.map{SidebarTabRow([$0])}}
        return regular[..<first].map{SidebarTabRow([$0])}
            + [SidebarTabRow(Array(regular[first...last]))]
            + regular[(last+1)...].map{SidebarTabRow([$0])}
    }
}
