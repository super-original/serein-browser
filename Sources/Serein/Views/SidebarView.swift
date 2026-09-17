import SwiftUI
import SereinCore

struct SidebarView: View {
    @Bindable var session: BrowserSession
    @Environment(\.appearsActive) private var active
    @State private var workspaceName=""
    @State private var creatingWorkspace=false
    @State private var renamingWorkspace: UUID?
    private var collapsed: Bool {session.state.sidebar == .collapsed}
    var body: some View {
        VStack(spacing:6) {
            if !collapsed {
                HStack(spacing:4) {
                    Spacer().frame(width:70)
                    Button("Collapse Sidebar",systemImage:"sidebar.left"){session.state.sidebar = .collapsed}.labelStyle(.iconOnly).help("Collapse Sidebar (⇧⌘S)")
                    Spacer(minLength:0)
                    NavigationButtons(session:session)
                }.buttonStyle(.plain).frame(height:42)
                AddressField(session:session)
            } else {Color.clear.frame(height:54)}
            if !session.state.visibleTabs.filter({$0.kind == .essential}).isEmpty {
                LazyVGrid(columns:[GridItem(.adaptive(minimum:36),spacing:6)],spacing:6) {
                    ForEach(session.state.visibleTabs.filter{$0.kind == .essential}){tab in tabRow(tab,essential:true)}
                }.padding(.vertical,3)
            }
            if !collapsed {
                HStack {
                    Text(session.state.workspaces.first{$0.id==session.state.activeWorkspaceID}?.name ?? "Workspace").font(.system(size:12,weight:.semibold)).foregroundStyle(.secondary)
                    Spacer()
                    if session.state.isPrivate {Image(systemName:"hand.raised").help("Private Browsing")}
                }.padding(.horizontal,8).padding(.top,8).padding(.bottom,12)
            }
            ScrollView {
                LazyVStack(spacing:4) {
                    ForEach(session.state.visibleTabs.filter{$0.kind == .pinned}){tab in tabRow(tab)}
                    Divider().padding(.vertical,8)
                    Button {session.newTab()} label:{HStack(spacing:10){Image(systemName:"plus");if !collapsed {Text("New Tab");Spacer()}}.frame(maxWidth:.infinity,alignment:.leading).padding(.horizontal,10).frame(height:36)}
                        .buttonStyle(.plain).foregroundStyle(.secondary).accessibilityIdentifier("new-tab")
                    ForEach(session.state.visibleTabs.filter{$0.kind == .regular}){tab in tabRow(tab)}
                }
            }.scrollIndicators(.hidden)
            if let host=session.extensions,!host.records.filter({$0.enabled}).isEmpty {
                ScrollView(.horizontal) {
                    HStack(spacing:6) {ForEach(host.records.filter{$0.enabled}){record in ExtensionActionButton(record:record,session:session,revision:host.actionRevision).frame(width:28,height:28)}}
                }.scrollIndicators(.hidden).frame(height:32)
            }
            HStack(spacing:6) {
                Menu {
                    Button("Bookmarks"){session.libraryPanel = .bookmarks}
                    Button("History"){session.libraryPanel = .history}
                    Button("Downloads"){session.libraryPanel = .downloads}
                    Button("Extensions"){session.libraryPanel = .extensions}
                    Button("Settings…"){session.libraryPanel = .settings}
                    Divider()
                    Button("Compact Mode"){session.state.sidebar = .compact;session.compactRevealed=false}
                    if collapsed {Button("Expand Sidebar"){session.state.sidebar = .expanded}}
                } label:{Image(systemName:"ellipsis.circle")}.menuStyle(.borderlessButton).fixedSize().help("Browser Menu")
                if !collapsed {
                    Spacer(minLength:0)
                    ForEach(session.state.workspaces){space in
                        Button {session.switchWorkspace(space.id)} label:{Image(systemName:space.id==session.state.activeWorkspaceID ? "circle.fill" : "circle").font(.system(size:space.id==session.state.activeWorkspaceID ? 8 : 6))}.buttonStyle(.plain).frame(width:20,height:28).help(space.name).accessibilityLabel("Workspace \(space.name)")
                        .contextMenu {
                            Button("Rename…"){workspaceName=space.name;renamingWorkspace=space.id;creatingWorkspace=true}
                            if session.state.workspaces.count>1 {Button("Remove Workspace (Keep Tabs)"){session.state.removeWorkspace(space.id)}}
                        }
                    }
                    Spacer(minLength:0)
                    Button("New Workspace",systemImage:"plus"){workspaceName="";renamingWorkspace=nil;creatingWorkspace=true}.labelStyle(.iconOnly).buttonStyle(.plain).help("New Workspace")
                }
            }.frame(height:30)
        }
        .padding(.horizontal,8).padding(.bottom,6)
        .opacity(active ? 1 : 0.65)
        .glassEffect(.regular,in:.rect(cornerRadius:12))
        .sheet(isPresented:$creatingWorkspace) {
            VStack(alignment:.leading,spacing:18) {
                Text("Workspace").font(.headline)
                TextField("Name",text:$workspaceName).textFieldStyle(.bordered)
                HStack {Button("Cancel"){creatingWorkspace=false}.keyboardShortcut(.cancelAction);Spacer();Button(renamingWorkspace == nil ? "Create" : "Rename"){
                    if let id=renamingWorkspace,let i=session.state.workspaces.firstIndex(where:{$0.id==id}) {session.state.workspaces[i].name=workspaceName.trimmingCharacters(in:.whitespacesAndNewlines)}
                    else {let id=session.state.addWorkspace(name:workspaceName);session.switchWorkspace(id)}
                    creatingWorkspace=false
                }.disabled(workspaceName.trimmingCharacters(in:.whitespacesAndNewlines).isEmpty).keyboardShortcut(.defaultAction)}
            }.padding(24).frame(width:320)
        }
    }
    private func tabRow(_ tab: BrowserTab,essential: Bool = false) -> some View {
        TabRow(session:session,tab:tab,compact:collapsed || essential)
            .draggable(tab.id.uuidString)
            .dropDestination(for:String.self){items,_ in guard let value=items.first,let id=UUID(uuidString:value) else{return false};session.move(id,before:tab.id);return true}
    }
}
private struct TabRow: View {
    let session: BrowserSession
    let tab: BrowserTab
    let compact: Bool
    @State private var hovering=false
    var body: some View {
        HStack(spacing:10) {
            Button {session.select(tab.id)} label: {
                HStack(spacing:10) {
                    Image(systemName:tab.kind == .essential ? "star.fill" : "globe").font(.system(size:14)).frame(width:16,height:16)
                    if !compact {Text(tab.title).font(.system(size:13,weight:session.state.selectedTabID==tab.id ? .semibold : .regular)).lineLimit(1);Spacer(minLength:0)}
                }.frame(maxWidth:.infinity,alignment:compact ? .center : .leading).contentShape(Rectangle())
            }.buttonStyle(.plain).accessibilityLabel(tab.title).accessibilityIdentifier("tab-\(tab.id)")
            if !compact,hovering,tab.kind == .regular {Button("Close Tab",systemImage:"xmark"){session.close(tab.id)}.labelStyle(.iconOnly).font(.system(size:10)).buttonStyle(.plain)}
        }
        .padding(.horizontal,10).frame(height:36)
        .background(session.state.selectedTabID==tab.id ? Color.primary.opacity(0.09) : hovering ? Color.primary.opacity(0.045) : Color.clear,in:.rect(cornerRadius:8))
        .onHover{hovering=$0}.help(tab.title+"\n"+tab.url)
        .contextMenu {
            Button("Duplicate Tab"){session.duplicate(tab.id)}
            Button(tab.kind == .pinned ? "Unpin Tab" : "Pin Tab"){session.setKind(tab.id,tab.kind == .pinned ? .regular : .pinned)}
            Button(tab.kind == .essential ? "Remove from Essentials" : "Add to Essentials"){session.setKind(tab.id,tab.kind == .essential ? .regular : .essential)}
            if let home=tab.homeURL {Button("Reset Pinned Tab"){if let url=URL(string:home){session.runtime(tab.id).load(url)}}}
            Menu("Move to Workspace") {ForEach(session.state.workspaces){space in Button(space.name){session.state.moveToWorkspace(tab.id,space.id)}}}
            if !session.state.isPrivate {Button("Move to New Window"){session.manager?.moveTab(tab.id,from:session)}}
            if tab.id != session.state.selectedTabID {Button("Split with Current Tab"){session.state.split(with:tab.id)};Button("Unload Tab…"){session.unload(tab.id)}}
            Divider()
            Button("Close Tab"){session.close(tab.id)}
        }
    }
}
