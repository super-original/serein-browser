import SwiftUI
import AppKit

struct LibraryPanelView: View {
    @Bindable var session: BrowserSession
    let panel: LibraryPanel
    @State private var query=""
    @State private var bookmarkEditor:BookmarkEditorRequest?
    @AppStorage("searchProvider") private var searchProvider=SearchProvider.duckDuckGo
    @AppStorage("restoreTabHistory") private var restoreTabHistory=false
    @AppStorage("appearance") private var appearance="system"
    @AppStorage("idleTabUnloadMinutes") private var idleTabUnloadMinutes=0
    @AppStorage("previewExternalPinnedLinks") private var previewExternalPinnedLinks=true
    var body: some View {
        VStack(alignment:.leading,spacing:16) {
            HStack {Text(panel.rawValue.capitalized).font(.title2.bold());Spacer();Button("Done"){session.libraryPanel=nil}.keyboardShortcut(.cancelAction)}
            if let manager=session.manager {
                switch panel {
                case .bookmarks,.history:
                    TextField("Search",text:$query).textFieldStyle(.bordered)
                    let records=panel == .bookmarks ? manager.library.bookmarks : manager.library.history
                    List(records.filter{query.isEmpty || $0.title.localizedCaseInsensitiveContains(query) || $0.url.localizedCaseInsensitiveContains(query)}) {record in
                        HStack {
                            Button {session.navigate(record.url);session.libraryPanel=nil} label:{VStack(alignment:.leading){Text(record.title).lineLimit(1);Text(record.url).font(.caption).foregroundStyle(.secondary).lineLimit(1)}}.buttonStyle(.plain)
                            Spacer()
                            if panel == .bookmarks {
                                Button("Edit…"){bookmarkEditor = .init(original:record,title:record.title,url:record.url)}.accessibilityIdentifier("bookmark-edit-\(record.id)")
                                Button("Remove",systemImage:"trash"){manager.library.removeBookmark(record.id)}.labelStyle(.iconOnly)
                            }
                        }
                    }
                    if panel == .history {Button("Clear History…"){session.confirm("Clear browsing history?",detail:"This removes the saved history from Serein.",yes:"Clear"){if $0{manager.library.clearHistory()}}}}
                case .downloads:
                    DownloadsPanelView(store:manager.downloads,session:session)
                case .extensions:
                    if session.state.isPrivate {ContentUnavailableView("Extensions are disabled in private windows",systemImage:"hand.raised")}
                    else {ExtensionListView(host:manager.extensions,session:session)}
                case .settings:
                    Form {
                        Picker("Search engine",selection:$searchProvider){ForEach(SearchProvider.allCases,id:\.self){provider in Text(provider.title).tag(provider)}}
                        Picker("Appearance",selection:$appearance){Text("System").tag("system");Text("Light").tag("light");Text("Dark").tag("dark")}
                        Picker("Sidebar",selection:$session.state.sidebar){Text("Expanded").tag(SidebarMode.expanded);Text("Collapsed").tag(SidebarMode.collapsed);Text("Compact").tag(SidebarMode.compact)}
                        Picker("Unload idle regular tabs",selection:$idleTabUnloadMinutes) {
                            Text("Off").tag(0);Text("After 15 minutes").tag(15);Text("After 30 minutes").tag(30);Text("After 1 hour").tag(60)
                        }
                        Text("Unloaded pages reload when selected. Edited, media, pinned, preview, extension and private tabs stay loaded; active downloads pause unloading. Some page state may be lost.").font(.caption).foregroundStyle(.secondary)
                        Toggle("Preview external links opened by pinned and essential tabs",isOn:$previewExternalPinnedLinks)
                        Toggle("Remember Back and Forward history between launches",isOn:Binding(get:{restoreTabHistory},set:{restoreTabHistory=$0;manager.setRestoresNavigation($0)}))
                        Text("Off by default. Saves additional page and form state on this Mac for regular web tabs. Private windows and tabs with detected edits on the current page are excluded. After a system or WebKit update, tabs reopen at their saved address instead.").font(.caption).foregroundStyle(.secondary)
                        Text("Tabs restore when you reopen Serein. Private windows use a separate, nonpersistent website data store and are excluded from saved sessions.").font(.callout).foregroundStyle(.secondary)
                        Button("Clear Website Data…") {
                            session.confirm("Clear cookies and website data?",detail:"This signs you out of websites in this browsing mode.",yes:"Clear") {yes in
                                if yes {session.dataStore.removeData(ofTypes:WKWebsiteDataStore.allWebsiteDataTypes(),modifiedSince:.distantPast){}}
                            }
                        }
                        SitePermissionSettings(session: session)
                        Text("Serein 0.1 — development build\nRequires macOS 27.0. Extension compatibility is incomplete. This build is not notarized.").font(.caption).foregroundStyle(.secondary)
                    }.formStyle(.grouped)
                }
                if let error=manager.library.error ?? manager.restorationError {Text(error).foregroundStyle(.red).textSelection(.enabled)}
            }
        }.padding(24).frame(width:600,height:480)
        .sheet(item:$bookmarkEditor){request in
            if let store=session.manager?.library {BookmarkEditorView(store:store,request:request)}
        }
    }
}
import SereinCore
import WebKit

private struct ExtensionListView: View {
    @State private var accessRecord:InstalledExtension?
    @Bindable var host: ExtensionHost
    let session: BrowserSession
    var body: some View {
        VStack(alignment:.leading,spacing:12) {
            Text("WebExtensions · Compatibility varies by API and manifest. Native Safari App Extensions, legacy Safari formats, and CRX2 are not supported. CRX3 signatures verify archive integrity, not store approval.").font(.callout).foregroundStyle(.secondary)
            Text("Per-site background access is not fully enforced in this build. Denying a site also disables the extension. Re-enabling it may restore background access to denied sites.").font(.caption).foregroundStyle(.secondary)
            List(host.records) {record in
                VStack(alignment:.leading,spacing:8) {
                    HStack {Text(record.name).bold();Text(record.version).foregroundStyle(.secondary);Spacer();Toggle("Enabled",isOn:Binding(get:{record.enabled},set:{enabled in Task{await host.setEnabled(record.id,enabled)}})).toggleStyle(.switch).fixedSize()}
                    if let errors=host.contextErrors[record.id],!errors.isEmpty {
                        Text(errors.joined(separator:"\n")).font(.caption).foregroundStyle(.red)
                            .textSelection(.enabled).accessibilityIdentifier("extension-errors-\(record.id)")
                    }
                    Button("Requested Access…"){accessRecord=record}.font(.caption).accessibilityIdentifier("extension-access-\(record.id)")
                    if let identity = record.packageIdentity {
                        Text("Verified original \(identity.format) · \(identity.extensionID)").font(.caption).foregroundStyle(.secondary).textSelection(.enabled)
                    }
                    HStack {
                        Button("Open Action"){Task{await host.performFromLibrary(record.id,in:session)}}.disabled(!record.enabled || !host.actionEnabled(record.id,in:session))
                        if let context=host.contexts[record.id],let url=context.optionsPageURL {Button("Options"){session.newTab(url:url.absoluteString);session.libraryPanel=nil}}
                        if let context=host.contexts[record.id],!context.commands.isEmpty {
                            Menu("Commands") {
                                ForEach(context.commands,id:\.id) {command in
                                    Button(command.title.isEmpty ? command.id : command.title) {
                                        Task{_ = await host.performCommandFromLibrary(record.id,commandID:command.id,in:session)}
                                    }
                                }
                            }
                        }
                        Menu("Current Site") {Button("Allow on This Site"){host.setCurrentSite(record.id,in:session,allow:true)};Button("Deny Site and Disable Extension"){Task{await host.denyCurrentSiteAndDisable(record.id,in:session)}}}.disabled(!record.enabled || host.contexts[record.id] == nil || !["http","https"].contains(session.current?.webView.url?.scheme?.lowercased() ?? ""))
                        Spacer()
                        if record.packageIdentity != nil { Button("Update Signed Package…") { host.chooseUpdate(record.id, in: session) } }
                        Button("Remove…"){host.confirmRemoval(record,in:session)}
                    }.font(.caption)
                    if record.packageIdentity?.format == "CRX3" {
                        HStack {
                            Button("Register Native Application…"){host.nativeMessaging.chooseRegistration(for:record,in:session)}
                            ForEach(host.nativeMessaging.registrations(for:record.id)){registration in
                                Menu(registration.manifest.name){Button("Revoke Access"){host.nativeMessaging.revoke(registration.id)}}
                            }
                        }.font(.caption)
                    }
                }.padding(.vertical,4).disabled(host.busyIDs.contains(record.id))
            }
            Button("Install Extension…"){host.chooseInstall(in:session)}
            if let error=host.error {
                HStack(alignment:.top) {
                    Text(error).foregroundStyle(.red).font(.caption).textSelection(.enabled)
                    Spacer()
                    Button("Dismiss"){host.error=nil}.accessibilityLabel("Dismiss extension operation error")
                }
            }
        }.sheet(item:$accessRecord){ExtensionAccessDetailsView(record:$0)}
    }
}

private struct SitePermissionSettings: View {
    let session: BrowserSession
    var body: some View {
        Section("Site Permissions") {
            Text(session.state.isPrivate ? "Choices stay in this private window and are discarded when it closes." : "Choices are saved for the exact requesting site and top-level site.")
                .font(.caption).foregroundStyle(.secondary)
            if let url = session.current?.webView.url, let origin = SiteOrigin(url: url) {
                Text(origin.key).font(.caption).textSelection(.enabled)
                ForEach(SiteCapability.allCases, id: \.self) { capability in
                    let key = SitePermissionKey(topLevel: origin, requesting: origin, capability: capability)
                    Picker(capability.rawValue.capitalized, selection: Binding(
                        get: { session.sitePermissions.policy.decision(for: [key]) },
                        set: { session.sitePermissions.set($0, for: [key]) }
                    )) {
                        Text("Ask").tag(SitePermissionDecision.ask)
                        Text("Allow").tag(SitePermissionDecision.allow)
                        Text("Deny").tag(SitePermissionDecision.deny)
                    }
                }
            }
            ForEach(session.sitePermissions.policy.records) { record in
                HStack {
                    VStack(alignment: .leading) {
                        Text("\(record.key.capability.rawValue.capitalized): \(record.decision.rawValue)")
                        Text("\(record.key.requesting.key) on \(record.key.topLevel.key)").font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button("Reset") { session.sitePermissions.set(.ask, for: [record.key]) }
                }
            }
            Button("Reset All Site Permissions") { session.sitePermissions.reset() }
                .disabled(session.sitePermissions.policy.records.isEmpty)
            Text("Changes apply to future requests. Reload a page to end an existing grant. macOS privacy controls still apply.")
                .font(.caption).foregroundStyle(.secondary)
            if let error = session.sitePermissions.error { Text(error).foregroundStyle(.red) }
        }
    }
}
