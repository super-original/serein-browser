import AppKit
import WebKit
import Observation
import SereinCore

@MainActor @Observable final class DownloadItem: NSObject, Identifiable, WKDownloadDelegate {
    var record:DownloadRecord
    var fraction=0.0
    nonisolated let id:UUID
    var name:String {record.name}
    var destination:URL? {record.destination}
    var privateMode:Bool {record.privateWindowID != nil}
    var finished:Bool {record.phase.isFinished}
    var isActive:Bool {record.phase.isActive}
    var canResume:Bool {resumeData != nil && !isActive && !retired}
    var byteSummary:String? {
        guard let received=record.receivedBytes else{return nil}
        let amount=ByteCountFormatter.string(fromByteCount:received,countStyle:.file)
        if let expected=record.expectedBytes,expected>0 {return "\(amount) of \(ByteCountFormatter.string(fromByteCount:expected,countStyle:.file))"}
        return amount
    }
    var status:String {
        switch record.phase {
        case .choosing:return "Choosing destination"
        case .downloading:return "Downloading"
        case .cancelling:return "Stopping…"
        case .paused:return "Paused"
        case .complete:return "Complete"
        case .failed:return record.detail.isEmpty ? "Failed" : record.detail
        case .cancelled:return record.detail.isEmpty ? "Cancelled" : record.detail
        case .interrupted:return record.detail
        }
    }
    @ObservationIgnored private var download:WKDownload?
    @ObservationIgnored fileprivate var resumeData:Data?
    @ObservationIgnored private var observation:NSKeyValueObservation?
    @ObservationIgnored private var savePanel:NSSavePanel?
    @ObservationIgnored private var retired=false
    @ObservationIgnored weak var store:DownloadStore?
    @ObservationIgnored weak var session:BrowserSession?
    init(record:DownloadRecord,store:DownloadStore,session:BrowserSession?=nil) {
        self.id=record.id;self.record=record;self.store=store;self.session=session;super.init()
    }
    func attach(_ download:WKDownload) {
        guard !retired else{download.cancel(nil);return}
        self.download=download;download.delegate=self
        observation=download.progress.observe(\.fractionCompleted,options:[.initial,.new]) { [weak self,weak download] _,change in
            let value=change.newValue ?? 0
            Task { @MainActor [weak self,weak download] in
                guard let self,let download,self.download === download,!self.retired else{return}
                self.fraction=min(1,max(0,value));self.readProgress(download)
            }
        }
    }
    private func readProgress(_ download:WKDownload) {
        record.receivedBytes=max(0,download.progress.completedUnitCount)
        if download.progress.totalUnitCount>0 {record.expectedBytes=download.progress.totalUnitCount}
    }
    private func changed() {if !privateMode {store?.save()}}
    func download(_ download:WKDownload,decideDestinationUsing response:URLResponse,suggestedFilename:String,completionHandler:@escaping @MainActor @Sendable (URL?)->Void) {
        guard !retired,self.download === download else{completionHandler(nil);return}
        record.receivedResponse(url:response.url,mimeType:response.mimeType,expectedBytes:response.expectedContentLength)
        record.name=(suggestedFilename as NSString).lastPathComponent
        if let destination {record.name=destination.lastPathComponent;record.phase = .downloading;changed();completionHandler(destination);return}
        let panel=NSSavePanel();savePanel=panel;panel.nameFieldStringValue=name;panel.canCreateDirectories=true
        let complete:(NSApplication.ModalResponse)->Void = { [weak self] response in
            guard let self,!self.retired else{completionHandler(nil);return}
            self.savePanel=nil
            guard self.record.phase != .cancelling else{completionHandler(nil);return}
            if response == .OK,let url=panel.url {self.record.destination=url;self.record.name=url.lastPathComponent;self.record.phase = .downloading;self.changed();completionHandler(url)}
            else {self.record.phase = .cancelled;self.record.completed=Date();self.changed();completionHandler(nil)}
        }
        if let window=session?.dialogWindow {panel.beginSheetModal(for:window,completionHandler:complete)} else {panel.begin(completionHandler:complete)}
    }
    func downloadDidFinish(_ download:WKDownload) {
        guard self.download === download,!retired else{return}
        readProgress(download);record.completed=Date()
        record.phase = .complete;record.detail="";fraction=1;resumeData=nil;self.download=nil;observation=nil;changed()
    }
    func download(_ download:WKDownload,didFailWithError error:Error,resumeData:Data?) {
        guard self.download === download,!retired,record.phase != .cancelling else{return}
        if record.phase == .cancelled {self.download=nil;observation=nil;return}
        readProgress(download);record.completed=Date()
        record.phase = .failed;record.detail=error.localizedDescription;self.resumeData=resumeData;self.download=nil;observation=nil;changed()
    }
    func cancel(pause:Bool=false) {
        if !pause,canResume {resumeData=nil;record.phase = .cancelled;record.completed=Date();record.detail="";changed();return}
        guard let download,isActive,record.phase != .cancelling else{return}
        readProgress(download)
        record.phase = .cancelling;changed()
        savePanel?.cancel(nil);savePanel=nil
        download.cancel { [weak self] data in
            guard let self,!self.retired,self.download === download else{return}
            self.readProgress(download)
            self.resumeData=pause ? data : nil
            self.record.phase = pause && data != nil ? .paused : .cancelled
            self.record.completed=self.record.phase == .paused ? nil : Date()
            self.record.detail=pause && data == nil ? "Stopped; this download did not provide resume data." : ""
            self.download=nil;self.observation=nil;self.changed()
        }
    }
    func resume(in session:BrowserSession) {
        guard canResume,let data=resumeData,
              (privateMode ? record.privateWindowID == session.state.id && session.state.isPrivate : !session.state.isPrivate),
              let webView=session.current?.webView else{return}
        self.session=session;record.phase = .downloading;record.completed=nil;record.detail="";resumeData=nil;changed()
        webView.resumeDownload(fromResumeData:data) { [weak self] download in
            guard let self,!self.retired else{download.cancel(nil);return}
            self.attach(download)
        }
    }
    func retire() {
        retired=true;record.phase = .cancelled;savePanel?.cancel(nil);savePanel=nil;download?.cancel(nil);download=nil;resumeData=nil;observation=nil
    }
    func reveal() {if let destination,FileManager.default.fileExists(atPath:destination.path){NSWorkspace.shared.activateFileViewerSelecting([destination])}}
}
@MainActor @Observable final class DownloadStore {
    var items:[DownloadItem]=[]
    var error:String?
    let file:URL
    let resumeDirectory:URL
    init(root:URL) {
        resumeDirectory=root.appendingPathComponent("DownloadResume",isDirectory:true)
        file=root.appendingPathComponent("downloads.json")
        do {
            if FileManager.default.fileExists(atPath:file.path) {
                items=try DownloadRecord.restoredHistory(Data(contentsOf:file)).map { record in
                    let item=DownloadItem(record:record,store:self)
                    if [.interrupted,.failed].contains(record.phase),
                       let data=try? Data(contentsOf:resumeFile(record.id)),!data.isEmpty {
                        item.resumeData=data
                        item.record.phase = .paused
                        item.record.detail=""
                    }
                    return item
                }
            }
        } catch {self.error="Could not restore downloads: \(error.localizedDescription)"}
    }
    func save() {
        do {
            for item in items where !item.privateMode {
                if let data=item.resumeData {
                    try PrivateFileStore.write(data,to:resumeFile(item.id))
                } else {try discardResume(item.id)}
            }
            try PrivateFileStore.write(DownloadRecord.encodedHistory(items.map(\.record)),to:file)
        }
        catch {self.error="Could not save downloads: \(error.localizedDescription)"}
    }
    private func resumeFile(_ id:UUID)->URL {resumeDirectory.appendingPathComponent(id.uuidString+".resume")}
    private func discardResume(_ id:UUID) throws {
        let url=resumeFile(id)
        if FileManager.default.fileExists(atPath:url.path){try FileManager.default.removeItem(at:url)}
    }
    @discardableResult func add(_ download:WKDownload,in session:BrowserSession,destination:URL?=nil)->DownloadItem {
        let record=DownloadRecord(source:download.originalRequest?.url,destination:destination,privateWindowID:session.state.isPrivate ? session.state.id : nil)
        let item=DownloadItem(record:record,store:self,session:session)
        items.insert(item,at:0);item.attach(download);if !item.privateMode {save()};return item
    }
    /// Request opaque WebKit resume data before process exit. Private items stay
    /// memory-only, including when a later consent check cancels termination.
    func prepareForTermination() async -> Bool {
        for item in items where item.isActive {item.cancel(pause:true)}
        let clock=ContinuousClock(),deadline=clock.now.advanced(by:.seconds(5))
        while clock.now<deadline {
            if !items.contains(where: \.isActive) {
                error=nil;save()
                return error==nil
            }
            try? await Task.sleep(for:.milliseconds(50))
        }
        error="Downloads are still stopping. Wait for them to pause and quit again."
        return false
    }
    func visible(in session:BrowserSession)->[DownloadItem] {
        items.filter{session.state.isPrivate ? $0.record.privateWindowID==session.state.id : !$0.privateMode}
    }
    func clearFinished(in session:BrowserSession) {
        let ids=Set(visible(in:session).filter(\.finished).map(\.id))
        if !session.state.isPrivate {
            do {for id in ids {try discardResume(id)}}
            catch {self.error="Could not remove download recovery data: \(error.localizedDescription)";return}
        }
        items.removeAll{ids.contains($0.id)};if !session.state.isPrivate {save()}
    }
    func closePrivateWindow(_ id:UUID) {
        for item in items where item.record.privateWindowID==id {item.retire()}
        items.removeAll{$0.record.privateWindowID==id}
    }
}
