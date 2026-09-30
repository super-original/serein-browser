import SwiftUI
import SereinCore

struct FolderRow:View {
    let session:BrowserSession
    let folder:TabFolder
    let compact:Bool
    @State private var hovering=false
    var body:some View {
        Button {session.state.toggleFolder(folder.id)} label:{
            HStack(spacing:10) {
                Image(systemName:folder.collapsed ? "folder" : "folder.fill").font(.system(size:16)).foregroundStyle(Color.accentColor).frame(width:16,height:16)
                if !compact {Text(folder.name).font(.system(size:13,weight:.semibold)).lineLimit(1);Spacer(minLength:0)}
            }.frame(maxWidth:.infinity,alignment:compact ? .center : .leading).padding(.horizontal,10).frame(height:36).contentShape(Rectangle())
        }.buttonStyle(.plain)
        .background(hovering ? Color.primary.opacity(0.045) : Color.clear,in:.rect(cornerRadius:8))
        .onHover{hovering=$0}.help(folder.name)
        .accessibilityLabel(folder.name).accessibilityValue(folder.collapsed ? "Collapsed folder" : "Expanded folder")
        .accessibilityIdentifier("folder-\(folder.id)")
        .draggable("folder:"+folder.id.uuidString)
        .dropDestination(for:String.self){values,_ in
            guard values.count==1,let value=values.first else{return false}
            if value.hasPrefix("folder:"),let id=UUID(uuidString:String(value.dropFirst(7))) {return session.state.moveFolder(id,into:folder.id)}
            guard let id=UUID(uuidString:value) else{return false}
            return session.moveTabIntoFolder(id,folder.id)
        }
        .contextMenu {
            Button("Rename Folder…"){session.folderEditor = .init(editingID:folder.id,name:folder.name)}
            Button("New Tab in Folder"){session.newTab(inFolder:folder.id)}
            Button("New Subfolder…"){session.folderEditor = .init(parentID:folder.id)}.disabled(session.state.folderDepth(folder.id)>=5)
            if let parent=folder.parentID {Button("Move Out of Parent Folder"){_ = session.state.moveFolder(folder.id,into:session.state.folder(parent)?.parentID)}}
            Menu("Move Folder to Workspace") {
                ForEach(session.state.workspaces.filter{$0.id != folder.workspaceID}){space in Button(space.name){session.moveFolder(folder.id,toWorkspace:space.id)}}
            }.disabled(session.state.workspaces.count<2)
            Divider()
            let siblings=session.state.pinnedItemIDs(in:folder.parentID,workspaceID:folder.workspaceID)
            Button("Move Folder Up"){session.state.shiftPinnedItem(folder.id,by:-1)}.disabled(siblings.first==folder.id)
            Button("Move Folder Down"){session.state.shiftPinnedItem(folder.id,by:1)}.disabled(siblings.last==folder.id)
            Divider()
            Button("Unpack Folder"){session.state.unpackFolder(folder.id)}
            Button("Delete Folder…"){session.deleteFolder(folder.id)}
        }
    }
}
struct FolderEditorView:View {
    let session:BrowserSession
    let request:FolderEditorRequest
    @State private var name:String
    @State private var error:String?
    @FocusState private var nameFocused:Bool
    init(session:BrowserSession,request:FolderEditorRequest) {self.session=session;self.request=request;_name=State(initialValue:request.name)}
    var body:some View {
        VStack(alignment:.leading,spacing:18) {
            Text(request.editingID==nil ? "New Folder" : "Rename Folder").font(.headline)
            TextField("Name",text:$name).textFieldStyle(.bordered).accessibilityIdentifier("folder-name").focused($nameFocused)
            if let error {Text(error).foregroundStyle(.red).font(.caption)}
            HStack {
                Button("Cancel"){session.folderEditor=nil}.keyboardShortcut(.cancelAction)
                Spacer()
                Button(request.editingID==nil ? "Create" : "Rename") {
                    if let id=request.editingID {
                        guard session.state.folder(id) != nil else{error="This folder is no longer available.";return}
                        session.state.renameFolder(id,to:name)
                    } else if session.createFolder(name:name,tabIDs:request.tabIDs,parentID:request.parentID)==nil {error="The workspace or selected tabs changed. Close this dialog and try again.";return}
                    session.folderEditor=nil
                }.keyboardShortcut(.defaultAction).disabled(name.trimmingCharacters(in:.whitespacesAndNewlines).isEmpty)
            }
        }.padding(24).frame(width:320).onAppear{nameFocused=true}
    }
}
