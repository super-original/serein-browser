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
    static var transferRepresentation:some TransferRepresentation {
        CodableRepresentation(contentType:UTType(exportedAs:"dev.serein.sidebar-item",conformingTo:.data))
    }
}

enum SidebarDropTarget {case beforeTab(UUID),afterTab(UUID),folder(UUID)}
extension BrowserSession {
    func sidebarDrag(_ id:UUID,kind:SidebarDragItem.Kind)->SidebarDragItem {
        SidebarDragItem(token:manager?.sidebarDragToken ?? UUID(),window:state.id,item:id,kind:kind)
    }
    @discardableResult func acceptSidebarDrop(_ items:[SidebarDragItem],at target:SidebarDropTarget)->Bool {
        guard items.count==1,let item=items.first,let manager,item.token==manager.sidebarDragToken,
              manager.windows.contains(where:{$0.session===self}),
              let source=manager.windows.first(where:{$0.session.state.id==item.window})?.session else{return false}
        // Each private window owns a distinct nonpersistent website store. A live
        // view cannot cross that boundary, even between two private windows.
        guard source===self || (!source.state.isPrivate && !state.isPrivate) else{return false}
        if item.kind == .folder {
            guard source===self,case .folder(let folder)=target,
                  source.state.folder(item.item)?.workspaceID==source.state.activeWorkspaceID,
                  state.folder(folder)?.workspaceID==state.activeWorkspaceID else{return false}
            return state.moveFolder(item.item,into:folder)
        }
        guard let tab=source.state.visibleTabs.first(where:{$0.id==item.item}) else{return false}
        switch target {
        case .beforeTab(let id),.afterTab(let id):
            guard id != tab.id,let destination=state.visibleTabs.first(where:{$0.id==id}),
                  tab.kind==destination.kind else{return false}
        case .folder(let id):
            guard tab.kind != .essential,state.folder(id)?.workspaceID==state.activeWorkspaceID else{return false}
        }
        if source !== self {
            manager.moveTab(item.item,from:source,to:self)
            guard state.tabs.contains(where:{$0.id==item.item}) else{return false}
        }
        switch target {
        case .beforeTab(let id):move(item.item,before:id)
        case .afterTab(let id):move(item.item,after:id)
        case .folder(let id):guard moveTabIntoFolder(item.item,id) else{return false}
        }
        if source !== self {window?.makeKeyAndOrderFront(nil)}
        return true
    }
}
