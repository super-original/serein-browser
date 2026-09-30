import Foundation

public struct TabFolder:Identifiable,Codable,Equatable,Sendable {
    public var id:UUID
    public var workspaceID:UUID
    public var parentID:UUID?
    public var name:String
    public var collapsed:Bool
    public var order:[UUID]
    public init(id:UUID=UUID(),workspaceID:UUID,parentID:UUID?=nil,name:String="Folder") {
        self.id=id;self.workspaceID=workspaceID;self.parentID=parentID
        self.name=name.trimmingCharacters(in:.whitespacesAndNewlines).isEmpty ? "Folder" : name
        collapsed=false;order=[]
    }
}
public struct PinnedSidebarRow:Identifiable,Equatable,Sendable {
    public let id:UUID
    public let depth:Int
    public let isFolder:Bool
}
extension BrowserWindowState {
    public func folder(_ id:UUID)->TabFolder? {folders?.first{$0.id==id}}
    public func folderDepth(_ id:UUID)->Int {
        var current:UUID?=id,seen=Set<UUID>()
        while let value=current,let item=folder(value),seen.insert(value).inserted {current=item.parentID}
        return seen.count
    }
    public func folderDescendants(_ id:UUID)->Set<UUID> {
        guard folder(id) != nil else{return []}
        var result:Set<UUID>=[id],changed=true
        while changed {
            changed=false
            for item in folders ?? [] where item.parentID.map(result.contains) == true {
                if result.insert(item.id).inserted {changed=true}
            }
        }
        return result
    }
    public func folderTabIDs(_ id:UUID)->[UUID] {
        let descendants=folderDescendants(id)
        return tabs.filter{$0.folderID.map(descendants.contains)==true}.map(\.id)
    }
    public func pinnedItemIDs(in parent:UUID?=nil,workspaceID:UUID?=nil)->[UUID] {
        let workspace=parent.flatMap{folder($0)?.workspaceID} ?? workspaceID ?? activeWorkspaceID
        let candidates=tabs.filter{$0.kind == .pinned && $0.glanceParentID==nil && $0.workspaceID==workspace && $0.folderID==parent}.map(\.id)
            + (folders ?? []).filter{$0.workspaceID==workspace && $0.parentID==parent}.map(\.id)
        let allowed=Set(candidates),order=parent.flatMap{folder($0)?.order} ?? pinnedOrder ?? []
        var seen=Set<UUID>()
        return (order+candidates).filter{allowed.contains($0) && seen.insert($0).inserted}
    }
    public var orderedPinnedTabs:[BrowserTab] {
        var order:[UUID]=[],seen=Set<UUID>()
        func append(_ parent:UUID?) {
            for id in pinnedItemIDs(in:parent) where seen.insert(id).inserted {
                if folder(id) != nil {append(id)} else{order.append(id)}
            }
        }
        append(nil)
        let byID=Dictionary(tabs.map{($0.id,$0)},uniquingKeysWith:{first,_ in first})
        return order.compactMap{byID[$0]}
    }
    public var pinnedSidebarRows:[PinnedSidebarRow] {
        var rows:[PinnedSidebarRow]=[],seen=Set<UUID>()
        func append(_ parent:UUID?,depth:Int) {
            guard depth<=5 else{return}
            for id in pinnedItemIDs(in:parent) where seen.insert(id).inserted {
                if let item=folder(id) {
                    rows.append(.init(id:id,depth:depth,isFolder:true))
                    if !item.collapsed {append(id,depth:depth+1)}
                    else if let selected=sidebarSelectedTabID,folderTabIDs(id).contains(selected),seen.insert(selected).inserted {
                        rows.append(.init(id:selected,depth:depth+1,isFolder:false))
                    }
                } else {rows.append(.init(id:id,depth:depth,isFolder:false))}
            }
        }
        append(nil,depth:0);return rows
    }
    public var sidebarTabIDs:[UUID] {
        visibleTabs.filter{$0.kind == .essential}.map(\.id)+pinnedSidebarRows.filter{!$0.isFolder}.map(\.id)+visibleTabs.filter{$0.kind == .regular}.map(\.id)
    }
    public func folderPath(_ id:UUID)->String {
        var names:[String]=[],cursor:UUID?=id,seen=Set<UUID>()
        while let current=cursor,let item=folder(current),seen.insert(current).inserted {names.insert(item.name,at:0);cursor=item.parentID}
        return names.joined(separator:" / ")
    }
    public mutating func moveFolderToWorkspace(_ id:UUID,_ workspace:UUID) {
        guard let item=folder(id),workspaces.contains(where:{$0.id==workspace}),item.workspaceID != workspace else{return}
        let descendants=folderDescendants(id),members=Set(folderTabIDs(id))
        forgetPinnedPosition(id)
        for index in (folders ?? []).indices where descendants.contains(folders![index].id) {
            folders?[index].workspaceID=workspace
            if folders?[index].id==id {folders?[index].parentID=nil}
        }
        for index in tabs.indices where members.contains(tabs[index].id) || tabs[index].glanceParentID.map(members.contains)==true {tabs[index].workspaceID=workspace}
        var order=pinnedItemIDs(workspaceID:workspace);if !order.contains(id){order.append(id)};setPinnedOrder(order,in:nil,workspaceID:workspace)
        repair()
    }
    @discardableResult public mutating func shiftPinnedItem(_ id:UUID,by offset:Int)->Bool {
        guard [-1,1].contains(offset) else{return false}
        let item=folder(id),tab=tabs.first{$0.id==id}
        guard item != nil || tab?.kind == .pinned else{return false}
        let parent=item?.parentID ?? tab?.folderID,workspace=item?.workspaceID ?? tab!.workspaceID
        var order=pinnedItemIDs(in:parent,workspaceID:workspace)
        guard let index=order.firstIndex(of:id),order.indices.contains(index+offset) else{return false}
        order.swapAt(index,index+offset);setPinnedOrder(order,in:parent,workspaceID:workspace);return true
    }
    public mutating func reorderPinnedTab(_ id:UUID,before target:UUID) {
        guard let destination=tabs.first(where:{$0.id==target}),destination.kind == .pinned,moveTabToFolder(id,destination.folderID) else{return}
        var order=pinnedItemIDs(in:destination.folderID,workspaceID:destination.workspaceID)
        order.removeAll{$0==id};if let position=order.firstIndex(of:target){order.insert(id,at:position)}
        setPinnedOrder(order,in:destination.folderID,workspaceID:destination.workspaceID)
    }
    private mutating func setPinnedOrder(_ order:[UUID],in parent:UUID?,workspaceID:UUID?=nil) {
        if let parent,let index=folders?.firstIndex(where:{$0.id==parent}) {folders?[index].order=order}
        else {
            let current=Set(pinnedItemIDs(workspaceID:workspaceID))
            pinnedOrder=(pinnedOrder ?? []).filter{!current.contains($0) && !order.contains($0)}+order
        }
    }
    mutating func forgetPinnedPosition(_ id:UUID) {
        pinnedOrder?.removeAll{$0==id}
        for index in (folders ?? []).indices {folders?[index].order.removeAll{$0==id}}
    }
    @discardableResult public mutating func createFolder(name:String,tabIDs:[UUID]=[],parentID:UUID?=nil)->UUID? {
        if let parentID {guard let parent=folder(parentID),parent.workspaceID==activeWorkspaceID,folderDepth(parentID)<5 else{return nil}}
        guard Set(tabIDs).count==tabIDs.count,tabIDs.allSatisfy({id in tabs.contains{$0.id==id && $0.workspaceID==activeWorkspaceID && $0.kind != .essential && $0.glanceParentID==nil}}) else{return nil}
        var order=pinnedItemIDs(in:parentID)
        let position=order.firstIndex(where:tabIDs.contains) ?? order.count
        let item=TabFolder(workspaceID:activeWorkspaceID,parentID:parentID,name:name)
        if folders==nil {folders=[]};folders?.append(item)
        for id in tabIDs {_=moveTabToFolder(id,item.id)}
        order.removeAll{tabIDs.contains($0)};order.insert(item.id,at:min(position,order.count));setPinnedOrder(order,in:parentID)
        return item.id
    }
    @discardableResult public mutating func moveTabToFolder(_ id:UUID,_ destination:UUID?)->Bool {
        guard let index=tabs.firstIndex(where:{$0.id==id}),tabs[index].kind != .essential,tabs[index].glanceParentID==nil else{return false}
        if let destination {guard let item=folder(destination),item.workspaceID==tabs[index].workspaceID else{return false}}
        forgetPinnedPosition(id)
        if tabs[index].kind != .pinned {tabs[index].kind = .pinned;tabs[index].homeURL=tabs[index].url}
        tabs[index].folderID=destination
        var order=pinnedItemIDs(in:destination,workspaceID:tabs[index].workspaceID);if !order.contains(id){order.append(id)};setPinnedOrder(order,in:destination,workspaceID:tabs[index].workspaceID)
        return true
    }
    public mutating func renameFolder(_ id:UUID,to name:String) {
        guard let index=folders?.firstIndex(where:{$0.id==id}) else{return}
        let value=name.trimmingCharacters(in:.whitespacesAndNewlines)
        if !value.isEmpty {folders?[index].name=value}
    }
    public mutating func toggleFolder(_ id:UUID) {
        guard let index=folders?.firstIndex(where:{$0.id==id}) else{return};folders?[index].collapsed.toggle()
    }
    @discardableResult public mutating func moveFolder(_ id:UUID,into destination:UUID?)->Bool {
        guard let item=folder(id),let index=folders?.firstIndex(where:{$0.id==id}) else{return false}
        let descendants=folderDescendants(id)
        if let destination {
            guard let parent=folder(destination),parent.workspaceID==item.workspaceID,!descendants.contains(destination) else{return false}
            let height=descendants.map{folderDepth($0)-folderDepth(id)+1}.max() ?? 1
            guard folderDepth(destination)+height<=5 else{return false}
        }
        forgetPinnedPosition(id);folders?[index].parentID=destination
        var order=pinnedItemIDs(in:destination,workspaceID:item.workspaceID);if !order.contains(id){order.append(id)};setPinnedOrder(order,in:destination,workspaceID:item.workspaceID)
        return true
    }
    /// Remove only the container, retaining its tabs and nested folders.
    public mutating func unpackFolder(_ id:UUID) {
        guard let item=folder(id) else{return}
        let children=pinnedItemIDs(in:id)
        var siblings=pinnedItemIDs(in:item.parentID,workspaceID:item.workspaceID)
        let position=siblings.firstIndex(of:id) ?? siblings.count
        siblings.removeAll{$0==id};siblings.insert(contentsOf:children,at:min(position,siblings.count))
        for index in tabs.indices where tabs[index].folderID==id {tabs[index].folderID=item.parentID}
        for index in (folders ?? []).indices where folders?[index].parentID==id {folders?[index].parentID=item.parentID}
        folders?.removeAll{$0.id==id};forgetPinnedPosition(id);setPinnedOrder(siblings,in:item.parentID,workspaceID:item.workspaceID)
    }
    /// Caller closes the captured tab set with document-bound consent first.
    public mutating func removeEmptyFolderTree(_ id:UUID) {
        guard folderTabIDs(id).isEmpty else{return}
        let descendants=folderDescendants(id)
        folders?.removeAll{descendants.contains($0.id)}
        for id in descendants {forgetPinnedPosition(id)}
    }
    public mutating func repairFolders() {
        let tabIDs=Set(tabs.map(\.id)),knownWorkspaces=Set(self.workspaces.map(\.id));var seen=Set<UUID>()
        folders=folders?.filter{!tabIDs.contains($0.id) && seen.insert($0.id).inserted}
        for index in (folders ?? []).indices {
            if let workspace=folders?[index].workspaceID,!knownWorkspaces.contains(workspace){folders?[index].workspaceID=activeWorkspaceID}
        }
        for index in (folders ?? []).indices {
            guard let item=folders?[index] else{continue}
            var cursor=item.parentID,chain:Set<UUID>=[item.id],valid=true
            while let id=cursor {
                guard let parent=folder(id),parent.workspaceID==item.workspaceID,chain.insert(id).inserted,chain.count<=5 else{valid=false;break}
                cursor=parent.parentID
            }
            if !valid {folders?[index].parentID=nil}
        }
        for index in tabs.indices {
            if let id=tabs[index].folderID,folder(id)?.workspaceID != tabs[index].workspaceID || tabs[index].kind != .pinned || tabs[index].glanceParentID != nil {tabs[index].folderID=nil}
        }
        let all=Set(tabs.filter{$0.kind == .pinned && $0.folderID==nil}.map(\.id)+(folders ?? []).filter{$0.parentID==nil}.map(\.id))
        seen=[];pinnedOrder=pinnedOrder?.filter{all.contains($0) && seen.insert($0).inserted}
        for index in (folders ?? []).indices {
            if let id=folders?[index].id {let order=pinnedItemIDs(in:id);folders?[index].order=order}
        }
    }
}
