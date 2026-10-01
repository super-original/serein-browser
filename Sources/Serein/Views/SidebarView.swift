import SwiftUI
import AppKit
import SereinCore

struct SidebarView: View {
    @Bindable var session: BrowserSession
    @Environment(\.appearsActive) private var active
    @State private var workspaceName=""
    @State private var creatingWorkspace=false
    @State private var renamingWorkspace: UUID?
    private var collapsed: Bool {session.state.sidebar == .collapsed}
    private var essentialColumns:[GridItem] {
        let count=session.state.visibleTabs.filter{$0.kind == .essential}.count
        let capacity=collapsed ? 1 : max(1,Int((session.state.sidebarWidth-10)/42))
        return Array(repeating:GridItem(.flexible(minimum:36),spacing:6),count:max(1,min(count,capacity)))
    }
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
                LazyVGrid(columns:essentialColumns,spacing:6) {
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
                    ForEach(session.state.pinnedSidebarRows){row in
                        Group {
                            if row.isFolder,let folder=session.state.folder(row.id) {FolderRow(session:session,folder:folder,compact:collapsed)}
                            else if let tab=session.state.tabs.first(where:{$0.id==row.id}) {tabRow(tab)}
                        }.padding(.leading,collapsed ? 0 : CGFloat(row.depth)*14)
                    }
                    Divider().padding(.vertical,8)
                    Button {session.newTab()} label:{HStack(spacing:10){Image(systemName:"plus");if !collapsed {Text("New Tab");Spacer()}}.frame(maxWidth:.infinity,alignment:.leading).padding(.horizontal,10).frame(height:36)}
                        .buttonStyle(.plain).foregroundStyle(.secondary).accessibilityIdentifier("new-tab")
                    ForEach(session.state.visibleTabs.filter{$0.kind == .regular}){tab in tabRow(tab)}
                }
            }.scrollIndicators(.hidden)
            if let host=session.extensions,!host.records.filter({$0.enabled && host.hasAction($0.id)}).isEmpty {
                ScrollView(.horizontal) {
                    HStack(spacing:6) {ForEach(host.records.filter{$0.enabled && host.hasAction($0.id)}){record in ExtensionActionButton(record:record,session:session,revision:host.actionRevision).frame(width:28,height:28)}}
                }.scrollIndicators(.hidden).frame(height:32)
            }
            HStack(spacing:6) {
                Menu {
                    Button("New Folder…"){session.folderEditor = .init()}
                    Divider()
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
                            if session.state.workspaces.count>1 {Button("Remove Workspace (Keep Tabs)"){session.removeWorkspace(space.id)}}
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
        .sheet(item:$session.folderEditor){request in FolderEditorView(session:session,request:request)}
        .sheet(isPresented:$creatingWorkspace) {
            VStack(alignment:.leading,spacing:18) {
                Text("Workspace").font(.headline)
                TextField("Name",text:$workspaceName).textFieldStyle(.bordered)
                HStack {Button("Cancel"){creatingWorkspace=false}.keyboardShortcut(.cancelAction);Spacer();Button(renamingWorkspace == nil ? "Create" : "Rename"){
                    if let id=renamingWorkspace,let i=session.state.workspaces.firstIndex(where:{$0.id==id}) {session.state.workspaces[i].name=workspaceName.trimmingCharacters(in:.whitespacesAndNewlines)}
                    else {session.addWorkspace(name:workspaceName)}
                    creatingWorkspace=false
                }.disabled(workspaceName.trimmingCharacters(in:.whitespacesAndNewlines).isEmpty).keyboardShortcut(.defaultAction)}
            }.padding(24).frame(width:320)
        }
    }
    private func tabRow(_ tab: BrowserTab,essential: Bool = false) -> some View {
        TabRow(session:session,tab:tab,compact:collapsed || essential)
            .draggable(session.sidebarDrag(tab.id,kind:.tab))
            .dropDestination(for:SidebarDragItem.self){items,point in
                session.acceptSidebarDrop(items,at:point.y>(tab.kind == .essential ? 22 : 18) ? .afterTab(tab.id) : .beforeTab(tab.id))
            }
    }
}
private struct TabRow: View {
    let session: BrowserSession
    let tab: BrowserTab
    let compact: Bool
    @State private var hovering=false
    var body: some View {
        HStack(spacing:10) {
            Button {session.clickTab(tab.id,modifiers:NSApp.currentEvent?.modifierFlags ?? [])} label: {
                HStack(spacing:10) {
                    if let icon=session.runtimes[tab.id]?.pageIcon {Image(nsImage:icon).resizable().interpolation(.high).scaledToFit().frame(width:16,height:16).accessibilityHidden(true)}
                    else {Image(systemName:tab.kind == .essential ? "star.fill" : "globe").font(.system(size:14)).frame(width:16,height:16).accessibilityHidden(true)}
                    if !compact {Text(tab.title).font(.system(size:13,weight:session.state.sidebarSelectedTabID==tab.id ? .semibold : .regular)).lineLimit(1);Spacer(minLength:0)}
                }.frame(maxWidth:.infinity,alignment:compact ? .center : .leading).contentShape(Rectangle())
            }.buttonStyle(.plain).accessibilityLabel(tab.title).accessibilityIdentifier("tab-\(tab.id)").accessibilityAddTraits(session.tabSelection.ids.contains(tab.id) || session.state.sidebarSelectedTabID==tab.id ? .isSelected : [])
            if session.state.glance(for:tab.id) != nil {
                Button {session.select(tab.id)} label:{Image(systemName:"rectangle.on.rectangle").font(.system(size:12)).frame(width:24,height:24)}.buttonStyle(.plain).accessibilityLabel("Show Link Preview").help("Show Link Preview")
            }
            if !compact,hovering,tab.kind == .regular {Button("Close Tab",systemImage:"xmark"){session.close(tab.id)}.labelStyle(.iconOnly).font(.system(size:10)).buttonStyle(.plain)}
        }
        .padding(.horizontal,10).frame(height:tab.kind == .essential ? 44 : 36)
        .background(session.state.sidebarSelectedTabID==tab.id ? Color.primary.opacity(0.09) : session.tabSelection.ids.contains(tab.id) ? Color.accentColor.opacity(0.16) : hovering ? Color.primary.opacity(0.045) : tab.kind == .essential ? Color.primary.opacity(0.045) : Color.clear,in:.rect(cornerRadius:8))
        .onHover{hovering=$0}.help(tab.title+"\n"+tab.url)
        .contextMenu {
            if session.tabSelection.ids.contains(tab.id),session.tabSelection.ids.count>1 {
                Button("Pin Selected Tabs"){session.setHighlightedKind(.pinned)}
                Button("Unpin Selected Tabs"){session.setHighlightedKind(.regular)}
                Menu("Move Selected Tabs to Workspace") {
                    ForEach(session.state.workspaces){space in Button(space.name){session.moveHighlightedToWorkspace(space.id)}}
                }
                Divider()
            }
            if tab.kind != .essential {
                let targets=session.tabSelection.ids.contains(tab.id) && session.tabSelection.ids.count>1 ? session.state.visibleTabs.filter{session.tabSelection.ids.contains($0.id)}.map(\.id) : [tab.id]
                Button(targets.count>1 ? "New Folder with Selected Tabs…" : "New Folder with Tab…"){session.folderEditor = .init(tabIDs:targets)}
                    .disabled(targets.contains{id in session.state.tabs.first{$0.id==id}?.kind == .essential})
                Menu("Move to Folder") {
                    ForEach((session.state.folders ?? []).filter{$0.workspaceID==tab.workspaceID}){folder in
                        Button(session.state.folderPath(folder.id)){session.moveTabIntoFolder(tab.id,folder.id)}.disabled(tab.folderID==folder.id)
                    }
                }.disabled(!(session.state.folders ?? []).contains{$0.workspaceID==tab.workspaceID})
                if tab.folderID != nil {Button("Remove from Folder"){session.moveTabIntoFolder(tab.id,nil)}}
                Divider()
            }
            Button("Duplicate Tab"){session.duplicate(tab.id)}
            Button(tab.kind == .pinned ? "Unpin Tab" : "Pin Tab"){session.setKind(tab.id,tab.kind == .pinned ? .regular : .pinned)}
            Button(tab.kind == .essential ? "Remove from Essentials" : "Add to Essentials"){session.setKind(tab.id,tab.kind == .essential ? .regular : .essential)}
            if let home=tab.homeURL {Button("Reset Pinned Tab"){if let url=URL(string:home){session.runtime(tab.id).load(url)}}}
            Menu("Move to Workspace") {ForEach(session.state.workspaces){space in Button(space.name){session.moveTabToWorkspace(tab.id,space.id)}}}
            if !session.state.isPrivate {Button("Move to New Window"){session.manager?.moveTab(tab.id,from:session)}}
            if session.tabSelection.ids.contains(tab.id),(2...4).contains(session.tabSelection.ids.count) {
                Button("Split Selected Tabs"){session.splitHighlighted()}
            }
            if !session.state.splitTabIDs.isEmpty,session.state.splitTabIDs.contains(tab.id) {Button("Exit Split View"){session.state.clearSplit()}}
            if tab.id != session.state.selectedTabID {Button("Split with Current Tab"){session.state.split(with:tab.id)};Button("Unload Tab…"){session.unload(tab.id)}.disabled(!session.canUnload(tab.id))}
            Divider()
            if session.tabSelection.ids.contains(tab.id),session.tabSelection.ids.count>1 {Button("Close \(session.tabSelection.ids.count) Selected Tabs"){session.closeHighlighted()}}
            Button("Close Tab"){session.close(tab.id)}
        }
    }
}
