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
                Image(systemName:folder.resolvedIcon?.rawValue ?? (folder.collapsed ? "folder" : "folder.fill")).font(.system(size:16)).foregroundStyle(Color.accentColor).frame(width:16,height:16)
                if !compact {Text(folder.name).font(.system(size:13,weight:.semibold)).lineLimit(1);Spacer(minLength:0)}
            }.frame(maxWidth:.infinity,alignment:compact ? .center : .leading).padding(.horizontal,10).frame(height:36).contentShape(Rectangle())
        }.buttonStyle(.plain)
        .background(hovering ? Color.primary.opacity(0.045) : Color.clear,in:.rect(cornerRadius:8))
        .onHover{hovering=$0}.help(folder.name)
        .accessibilityLabel(folder.name).accessibilityValue(folder.collapsed ? "Collapsed folder" : "Expanded folder")
        .accessibilityIdentifier("folder-\(folder.id)")
        .draggable(session.sidebarDrag(folder.id,kind:.folder))
        .dropDestination(for:SidebarDragItem.self){items,_ in session.acceptSidebarDrop(items,at:.folder(folder.id))}
        .contextMenu {
            Button("Edit Folder…"){session.folderEditor = .init(editingID:folder.id,name:folder.name)}
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
            Button("Convert Folder to Workspace"){session.convertFolderToWorkspace(folder.id)}
            Button("Unpack Folder"){session.state.unpackFolder(folder.id)}
            Button("Delete Folder…"){session.deleteFolder(folder.id)}
        }
    }
}
struct FolderEditorView:View {
    let session:BrowserSession
    let request:FolderEditorRequest
    @State private var name:String
    @State private var icon:FolderIcon?
    @State private var error:String?
    @FocusState private var nameFocused:Bool
    init(session:BrowserSession,request:FolderEditorRequest) {self.session=session;self.request=request;_name=State(initialValue:request.name);_icon=State(initialValue:request.editingID.flatMap{session.state.folder($0)?.resolvedIcon})}
    var body:some View {
        VStack(alignment:.leading,spacing:18) {
            Text(request.editingID==nil ? "New Folder" : "Edit Folder").font(.headline)
            TextField("Name",text:$name).textFieldStyle(.bordered).accessibilityIdentifier("folder-name").focused($nameFocused).onSubmit{save()}
            Text("Icon").font(.subheadline)
            LazyVGrid(columns:Array(repeating:GridItem(.fixed(48)),count:5),spacing:8) {
                iconButton(nil,label:"Default Folder")
                ForEach(FolderIcon.allCases,id:\.rawValue) { choice in iconButton(choice,label:iconLabel(choice)) }
            }
            if let error {Text(error).foregroundStyle(.red).font(.caption)}
            HStack {
                Button("Cancel"){session.folderEditor=nil}.keyboardShortcut(.cancelAction)
                Spacer()
                Button(request.editingID==nil ? "Create" : "Save"){save()}
                    .keyboardShortcut(.defaultAction).disabled(name.trimmingCharacters(in:.whitespacesAndNewlines).isEmpty)
            }
        }.padding(24).frame(width:320).onAppear{nameFocused=true}
    }
    private func iconLabel(_ icon:FolderIcon)->String {
        switch icon {
        case .star:"Star"
        case .book:"Book"
        case .work:"Work"
        case .travel:"Travel"
        case .code:"Code"
        case .music:"Music"
        case .heart:"Heart"
        case .science:"Science"
        }
    }
    private func iconButton(_ choice:FolderIcon?,label:String)->some View {
        Button {icon=choice} label:{
            Image(systemName:choice?.rawValue ?? "folder.fill").font(.system(size:18))
                .frame(width:32,height:28)
        }.buttonStyle(.bordered).tint(icon==choice ? Color.accentColor : Color.secondary)
            .help(label).accessibilityLabel(label).accessibilityValue(icon==choice ? "Selected" : "")
            .accessibilityIdentifier("folder-icon-"+(choice?.rawValue ?? "default"))
    }
    private func save() {
        guard !name.trimmingCharacters(in:.whitespacesAndNewlines).isEmpty else{return}
        if let id=request.editingID {
            guard session.state.folder(id) != nil else{error="This folder is no longer available.";return}
            session.state.renameFolder(id,to:name)
            if let index=session.state.folders?.firstIndex(where:{$0.id==id}) {session.state.folders?[index].userIcon=icon?.rawValue}
        } else {
            guard let id=session.createFolder(name:name,tabIDs:request.tabIDs,parentID:request.parentID),
                  let index=session.state.folders?.firstIndex(where:{$0.id==id}) else {
                error="The workspace or selected tabs changed. Close this dialog and try again.";return
            }
            session.state.folders?[index].userIcon=icon?.rawValue
        }
        session.folderEditor=nil
    }

}
