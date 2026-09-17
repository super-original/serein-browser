import AppKit
import WebKit
import Observation

@MainActor @Observable final class DownloadItem: NSObject, Identifiable, WKDownloadDelegate {
    let id=UUID()
    var name="Download"
    var status="Choosing destination"
    var destination: URL?
    var finished=false
    let privateMode: Bool
    @ObservationIgnored let download: WKDownload
    @ObservationIgnored weak var window: NSWindow?
    init(download: WKDownload, privateMode: Bool, window: NSWindow?) {self.download=download;self.privateMode=privateMode;self.window=window;super.init();download.delegate=self}
    func download(_ download: WKDownload,decideDestinationUsing response: URLResponse,suggestedFilename: String,completionHandler: @escaping @MainActor @Sendable (URL?)->Void) {
        name=(suggestedFilename as NSString).lastPathComponent
        let panel=NSSavePanel();panel.nameFieldStringValue=name;panel.canCreateDirectories=true
        let complete: (NSApplication.ModalResponse)->Void = {[weak self] response in
            guard let self else{completionHandler(nil);return}
            if response == .OK,let url=panel.url {self.destination=url;self.status="Downloading";completionHandler(url)}
            else {self.status="Cancelled";self.finished=true;completionHandler(nil)}
        }
        if let window {panel.beginSheetModal(for:window,completionHandler:complete)} else {panel.begin(completionHandler:complete)}
    }
    func downloadDidFinish(_ download: WKDownload) {status="Complete";finished=true}
    func download(_ download: WKDownload,didFailWithError error: Error,resumeData: Data?) {status=error.localizedDescription;finished=true}
    func cancel() {download.cancel{_ in};status="Cancelled";finished=true}
    func reveal() {if let destination {NSWorkspace.shared.activateFileViewerSelecting([destination])}}
}
@MainActor @Observable final class DownloadStore {
    var items: [DownloadItem] = []
    func add(_ download: WKDownload,privateMode: Bool,window: NSWindow?) {items.insert(DownloadItem(download:download,privateMode:privateMode,window:window),at:0)}
    func clearFinished(privateMode: Bool) {items.removeAll{$0.finished && $0.privateMode==privateMode}}
}
