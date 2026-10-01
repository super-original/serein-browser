import Foundation

/// Transient highlighted tabs, distinct from the one active page.
public struct TabSelection: Equatable, Sendable {
    public private(set) var ids:Set<UUID>=[]
    public private(set) var anchor:UUID?
    public init() {}
    public mutating func selectOnly(_ id:UUID?) {ids=Set(id.map{[$0]} ?? []);anchor=id}
    public mutating func set(_ id:UUID,selected:Bool) {if selected {ids.insert(id)} else {ids.remove(id)}}
    public mutating func toggle(_ id:UUID) {set(id,selected:!ids.contains(id));anchor=id}
    public mutating func range(to id:UUID,in order:[UUID],additive:Bool=false) {
        guard let end=order.firstIndex(of:id) else{return}
        let start=anchor.flatMap{order.firstIndex(of:$0)} ?? end
        let range=Set(order[min(start,end)...max(start,end)])
        ids=additive ? ids.union(range) : range
        if anchor.map({!order.contains($0)}) ?? true {anchor=id}
    }
    public mutating func retain(_ valid:Set<UUID>) {
        ids.formIntersection(valid)
        if let anchor,!valid.contains(anchor) {self.anchor=nil}
    }
}
