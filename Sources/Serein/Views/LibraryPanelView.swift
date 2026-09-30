import SwiftUI
import AppKit

struct LibraryPanelView: View {
    @Bindable var session: BrowserSession
    let panel: LibraryPanel
    @State private var query=""
    @AppStorage("appearance") private var appearance="system"
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
                            if panel == .bookmarks {Button("Remove",systemImage:"trash"){manager.library.removeBookmark(record.id)}.labelStyle(.iconOnly)}
                        }
                    }
                    if panel == .history {Button("Clear History…"){session.confirm("Clear browsing history?",detail:"This removes the saved history from Serein.",yes:"Clear"){if $0{manager.library.clearHistory()}}}}
                case .downloads:
                    List(manager.downloads.items.filter{$0.privateMode==session.state.isPrivate}) {item in
                        HStack {VStack(alignment:.leading){Text(item.name);Text(item.status).font(.caption).foregroundStyle(.secondary)};Spacer();if !item.finished {Button("Cancel"){item.cancel()}};if item.destination != nil,item.finished {Button("Show in Finder"){item.reveal()}}}
                    }
                    Button("Clear Finished"){manager.downloads.clearFinished(privateMode:session.state.isPrivate)}
                case .extensions:
                    if session.state.isPrivate {ContentUnavailableView("Extensions are disabled in private windows",systemImage:"hand.raised")}
                    else {ExtensionListView(host:manager.extensions,session:session)}
                case .settings:
                    Form {
                        Picker("Appearance",selection:$appearance){Text("System").tag("system");Text("Light").tag("light");Text("Dark").tag("dark")}
                        Picker("Sidebar",selection:$session.state.sidebar){Text("Expanded").tag(SidebarMode.expanded);Text("Collapsed").tag(SidebarMode.collapsed);Text("Compact").tag(SidebarMode.compact)}
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
    }
}
import SereinCore
import WebKit

private struct ExtensionListView: View {
    @Bindable var host: ExtensionHost
    let session: BrowserSession
    var body: some View {
        VStack(alignment:.leading,spacing:12) {
            Text("WebExtensions · Compatibility varies by API and manifest. Native Safari App Extensions, legacy Safari formats, and CRX packages are not supported.").font(.callout).foregroundStyle(.secondary)
            List(host.records) {record in
                VStack(alignment:.leading,spacing:8) {
                    HStack {Text(record.name).bold();Text(record.version).foregroundStyle(.secondary);Spacer();Toggle("Enabled",isOn:Binding(get:{record.enabled},set:{enabled in Task{await host.setEnabled(record.id,enabled)}})).toggleStyle(.switch).fixedSize()}
                    HStack {
                        Button("Open Action"){host.perform(record.id,in:session)}.disabled(!record.enabled)
                        if let context=host.contexts[record.id],let url=context.optionsPageURL {Button("Options"){session.newTab(url:url.absoluteString);session.libraryPanel=nil}}
                        Menu("Current Site") {Button("Allow Until Quit"){host.setCurrentSite(record.id,in:session,allow:true)};Button("Deny Until Quit"){host.setCurrentSite(record.id,in:session,allow:false)}}.disabled(!record.enabled)
                        Spacer()
                        Button("Remove…"){session.confirm("Remove \(record.name)?",detail:"The package and extension settings will be removed. Some extension website data may remain; use Clear Website Data in Settings to remove it.",yes:"Remove"){yes in if yes{Task{await host.remove(record.id)}}}}
                    }.font(.caption)
                }.padding(.vertical,4)
            }
            Button("Install Extension…"){host.chooseInstall(in:session)}
            if let error=host.error {Text(error).foregroundStyle(.red).font(.caption).textSelection(.enabled)}
        }
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
