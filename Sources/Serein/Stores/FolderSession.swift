import AppKit
import WebKit
import SereinCore

struct FolderEditorRequest:Identifiable {
    let id=UUID()
    var editingID:UUID?
    var parentID:UUID?
    var tabIDs:[UUID]=[]
    var name="New Folder"
}
extension BrowserSession {
    @discardableResult func createFolder(name:String,tabIDs:[UUID]=[],parentID:UUID?=nil)->UUID? {
        guard let id=state.createFolder(name:name,tabIDs:tabIDs,parentID:parentID) else{return nil}
        for tab in tabIDs {extensions?.controller.didChangeTabProperties(.pinned,for:bridge(tab))}
        return id
    }
    @discardableResult func moveTabIntoFolder(_ id:UUID,_ folder:UUID?)->Bool {
        guard state.moveTabToFolder(id,folder) else{return false}
        extensions?.controller.didChangeTabProperties(.pinned,for:bridge(id));return true
    }
    func newTab(inFolder id:UUID) {
        guard state.folder(id)?.workspaceID==state.activeWorkspaceID else{return}
        let tab=newTab();moveTabIntoFolder(tab,id)
        if let index=state.folders?.firstIndex(where:{$0.id==id}) {state.folders?[index].collapsed=false}
    }
    func deleteFolder(_ id:UUID) {
        guard let folder=state.folder(id) else{return}
        let ids=state.folderTabIDs(id),tree=state.folderDescendants(id)
        let documents=ids.flatMap{state.closingTabIDs($0)}.map{(id:$0,document:runtimes[$0]?.documentID)}
        confirm("Delete \(folder.name)?",detail:"This closes \(ids.count) tabs and removes this folder and its subfolders. Unsaved page changes may be lost. Choose Unpack Folder instead to keep its tabs.",yes:"Delete Folder") { [weak self] allowed in
            guard allowed,let self,self.state.folderDescendants(id)==tree,self.state.folderTabIDs(id)==ids,
                  documents.allSatisfy({target in self.state.tabs.contains(where:{$0.id==target.id}) && self.runtimes[target.id]?.documentID==target.document}) else{return}
            for tab in ids {self.close(tab,ask:false)}
            self.state.removeEmptyFolderTree(id)
        }
    }
    func moveFolder(_ id:UUID,toWorkspace workspace:UUID) {
        changeWorkspace{$0.moveFolderToWorkspace(id,workspace)}
    }
}
