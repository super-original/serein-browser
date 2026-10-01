import SwiftUI
import UniformTypeIdentifiers
import SereinCore

/// App-private, typed drag data. IDs alone from text/file drops cannot move tabs.
struct SidebarDragItem:Codable,Transferable,Sendable {
    enum Kind:String,Codable,Sendable {case tab,folder}
    let token:UUID
    let window:UUID
    let item:UUID
    let kind:Kind
    var selectedTabs:[UUID]? = nil
    static var transferRepresentation:some TransferRepresentation {
        CodableRepresentation(contentType:UTType(exportedAs:"dev.serein.sidebar-item",conformingTo:.data))
    }
}

enum SidebarDropTarget {case beforeTab(UUID),afterTab(UUID),folder(UUID),beforeFolder(UUID),afterFolder(UUID)}
extension BrowserSession {
    func sidebarDrag(_ id:UUID,kind:SidebarDragItem.Kind)->SidebarDragItem {
        let visibleOrder=state.sidebarTabIDs
        let order=visibleOrder+state.visibleTabs.filter{!visibleOrder.contains($0.id)}.map(\.id)
        let selected=kind == .tab && tabSelection.ids.contains(id) && tabSelection.ids.count>1
            ? order.filter{tabSelection.ids.contains($0)} : nil
        return SidebarDragItem(token:manager?.sidebarDragToken ?? UUID(),window:state.id,item:id,kind:kind,selectedTabs:selected)
    }
    @discardableResult func acceptSidebarDrop(_ items:[SidebarDragItem],at target:SidebarDropTarget)->Bool {
        guard items.count==1,let item=items.first,let manager,item.token==manager.sidebarDragToken,
              manager.windows.contains(where:{$0.session===self}),
              let source=manager.windows.first(where:{$0.session.state.id==item.window})?.session else{return false}
        // Each private window owns a distinct nonpersistent website store. A live
        // view cannot cross that boundary, even between two private windows.
        guard source===self || (!source.state.isPrivate && !state.isPrivate) else{return false}
        if item.kind == .folder {
            guard source===self,state.folder(item.item)?.workspaceID==state.activeWorkspaceID else{return false}
            switch target {
            case .folder(let folder):
                guard state.folder(folder)?.workspaceID==state.activeWorkspaceID else{return false}
                return state.moveFolder(item.item,into:folder)
            case .beforeFolder(let folder),.afterFolder(let folder):
                guard state.folder(folder)?.workspaceID==state.activeWorkspaceID else{return false}
                let after:Bool
                if case .afterFolder=target {after=true} else{after=false}
                return state.placeFolder(item.item,beside:folder,after:after)
            case .beforeTab,.afterTab:return false
            }
        }
        let ids=item.selectedTabs ?? [item.item],unique=Set(ids)
        // Validate the whole captured group before moving any live view. A stale
        // member, duplicate or foreign category must not cause a partial move.
        guard !ids.isEmpty,unique.count==ids.count,unique.contains(item.item) else{return false}
        let tabs=ids.compactMap{id in source.state.visibleTabs.first{$0.id==id}}
        guard tabs.count==ids.count else{return false}
        switch target {
        case .beforeFolder,.afterFolder:return false
        case .beforeTab(let id),.afterTab(let id):
            guard !unique.contains(id),let destination=state.visibleTabs.first(where:{$0.id==id}),
                  tabs.allSatisfy({$0.kind==destination.kind}) else{return false}
        case .folder(let id):
            guard tabs.allSatisfy({$0.kind != .essential}),state.folder(id)?.workspaceID==state.activeWorkspaceID else{return false}
        }
        if source !== self {
            for id in ids {manager.moveTab(id,from:source,to:self)}
            guard ids.allSatisfy({id in state.tabs.contains{$0.id==id}}) else{return false}
        }
        switch target {
        case .beforeFolder,.afterFolder:return false
        case .beforeTab(let target):for id in ids {move(id,before:target)}
        case .afterTab(let target):for id in ids.reversed() {move(id,after:target)}
        case .folder(let target):for id in ids {guard moveTabIntoFolder(id,target) else{return false}}
        }
        if ids.count>1 {
            let previous=state.selectedTabID,highlighted=tabSelection.ids
            tabSelection.selectOnly(item.item)
            for id in ids {tabSelection.set(id,selected:true)}
            state.select(item.item)
            publishSelection(previousActive:previous,previousHighlighted:highlighted)
        }
        if source !== self {window?.makeKeyAndOrderFront(nil)}
        return true
    }
}
