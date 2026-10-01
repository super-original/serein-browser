import SwiftUI
import AppKit
import SereinCore

struct DownloadsPanelView:View {
    @Bindable var store:DownloadStore
    let session:BrowserSession
    @State private var query=""
    @State private var filter=DownloadListFilter.all
    private var visible:[DownloadItem] {store.visible(in:session,query:query,filter:filter)}
    var body:some View {
        VStack(alignment:.leading,spacing:12) {
            TextField("Search downloads",text:$query).textFieldStyle(.bordered).accessibilityIdentifier("downloads-search")
            Picker("Show",selection:$filter) {
                ForEach(DownloadListFilter.allCases,id:\.self){Text($0.title).tag($0)}
            }.pickerStyle(.segmented)
            List(visible) {item in
                HStack {
                    VStack(alignment:.leading) {
                        Text(item.name).lineLimit(1)
                        Text(item.status).font(.caption).foregroundStyle(.secondary)
                        if let bytes=item.byteSummary {Text(bytes).font(.caption).foregroundStyle(.secondary)}
                    }
                    Spacer()
                    if item.isActive {
                        ProgressView(value:item.fraction).frame(width:70)
                        Button("Pause"){item.cancel(pause:true)}
                        Button("Cancel"){item.cancel()}
                    }
                    if item.canResume {Button("Resume"){item.resume(in:session)};Button("Cancel"){item.cancel()}}
                    if let destination=item.destination,item.finished {
                        Button("Show in Finder"){item.reveal()}.disabled(!FileManager.default.fileExists(atPath:destination.path))
                    }
                    if item.finished {
                        Button("Remove from History"){store.removeFinished([item.id],in:session)}
                            .help("Remove this record without deleting the downloaded file")
                            .accessibilityIdentifier("download-remove-\(item.id)")
                    }
                }
            }.overlay {if visible.isEmpty {ContentUnavailableView(query.isEmpty ? "No downloads" : "No matching downloads",systemImage:"arrow.down.circle")}}
            HStack {
                Text("\(visible.count) shown").font(.caption).foregroundStyle(.secondary).accessibilityIdentifier("downloads-result-count")
                Spacer()
                Button("Clear All Finished"){store.clearFinished(in:session)}
                    .disabled(!store.visible(in:session).contains(where:\.finished))
            }
            Text(session.state.isPrivate ? "Private downloads can resume while this window stays open. Closing it forgets their history; saved files remain on disk." : "Paused downloads can resume after reopening Serein. Saved files remain where you chose to download them.").font(.caption).foregroundStyle(.secondary)
            if let error=store.error {Text(error).foregroundStyle(.red)}
        }
    }
}
