import AppKit
import WebKit
import Foundation
import SereinCore

/// Exercises production downloads, including the native destination sheet.
/// Separate DownloadRestartVerification covers recovery in a fresh process.
@MainActor enum DownloadVerification {
    static func run(manager:BrowserManager,session:BrowserSession,root:URL) async -> [RuntimeVerification.Result] {
        var results:[RuntimeVerification.Result]=[]
        func check(_ name:String,_ passed:Bool,_ detail:String="") {results.append(.init(name:name,passed:passed,detail:detail))}
        func wait(_ condition:@MainActor ()->Bool) async -> Bool {
            for _ in 0..<150 {if condition(){return true};try? await Task.sleep(for:.milliseconds(100))};return false
        }
        func start(_ name:String,in owner:BrowserSession,destination:String?) async -> DownloadItem {
            await withCheckedContinuation {continuation in
                owner.current!.webView.startDownload(using:URLRequest(url:URL(string:"http://127.0.0.1:8765/"+name)!)) {download in
                    continuation.resume(returning:manager.downloads.add(download,in:owner,destination:destination.map{root.appendingPathComponent($0)}))
                }
            }
        }
        session.window?.makeKeyAndOrderFront(nil)
        let native=await start("download.txt",in:session,destination:nil)
        let presented=await wait{session.window?.attachedSheet is NSSavePanel}
        check("download-save-panel-visible",presented)
        if let panel=session.window?.attachedSheet as? NSSavePanel {
            try? "prepare-save-download".write(to:root.appendingPathComponent("keyboard-request"),atomically:true,encoding:.utf8)
            _=await wait{FileManager.default.fileExists(atPath:root.appendingPathComponent("prepare-save-download.keyboard-finished").path)}
            let capture="21-download-save-panel"
            try? capture.write(to:root.appendingPathComponent("capture-request"),atomically:true,encoding:.utf8)
            let captured=await wait{FileManager.default.fileExists(atPath:root.appendingPathComponent(capture+".capture-finished").path)}
            check("download-save-panel-capture",captured && FileManager.default.fileExists(atPath:root.appendingPathComponent(capture+".png").path))
            try? "save-download".write(to:root.appendingPathComponent("keyboard-request"),atomically:true,encoding:.utf8)
            _=await wait{native.finished}
            check("download-native-save-completes",native.record.phase == .complete,native.status)
            check("download-native-save-destination",native.destination?.resolvingSymlinksInPath().standardizedFileURL == root.appendingPathComponent("native-save-result.txt").resolvingSymlinksInPath().standardizedFileURL,String(describing:native.destination))
            check("download-native-save-content",native.destination.flatMap{try? String(contentsOf:$0,encoding:.utf8)} == "Serein deterministic download fixture v1.\n")
            if !native.finished {panel.cancel(nil)}
        }
        let cancelledPanel=await start("download.txt",in:session,destination:nil)
        _=await wait{session.window?.attachedSheet is NSSavePanel}
        (session.window?.attachedSheet as? NSSavePanel)?.cancel(nil)
        _=await wait{cancelledPanel.finished}
        check("download-native-save-cancel",cancelledPanel.record.phase == .cancelled && cancelledPanel.destination == nil,cancelledPanel.status)
        let item=await start("download.txt",in:session,destination:"download-result.txt")
        let completed=await wait{item.finished}
        check("download-production-completes",completed && item.record.phase == .complete,item.status)
        check("download-content",item.destination.flatMap{try? String(contentsOf:$0,encoding:.utf8)} == "Serein deterministic download fixture v1.\n")
        let restored=DownloadStore(root:root)
        check("download-history-restores",restored.items.contains{$0.id==item.id && $0.record.phase == .complete && $0.destination==item.destination},restored.error ?? "")
        let redirected=await start("redirect-download",in:session,destination:"redirected-download.txt")
        _=await wait{redirected.finished}
        let expectedBytes=Int64("Serein deterministic download fixture v1.\n".utf8.count)
        check("download-redirect-response-metadata",redirected.record.phase == .complete && redirected.record.source?.path=="/redirect-download" && redirected.record.finalURL?.path=="/download.txt" && redirected.record.mimeType=="text/plain",String(describing:redirected.record))
        check("download-final-byte-count",redirected.record.receivedBytes==expectedBytes && redirected.record.expectedBytes==expectedBytes && redirected.record.completed != nil,redirected.byteSummary ?? "No count")
        let restoredMetadata=DownloadStore(root:root).items.first{$0.id==redirected.id}?.record
        check("download-response-metadata-restores",restoredMetadata?.finalURL==redirected.record.finalURL && restoredMetadata?.receivedBytes==expectedBytes && restoredMetadata?.completed==redirected.record.completed)

        let historyBefore=try? Data(contentsOf:manager.downloads.file)
        let modifiedBefore=(try? FileManager.default.attributesOfItem(atPath:manager.downloads.file.path))?[.modificationDate] as? Date
        let privateA=manager.newWindow(isPrivate:true),privateB=manager.newWindow(isPrivate:true)
        let a=await start("download.txt",in:privateA,destination:"private-a-download.txt")
        let b=await start("download.txt",in:privateB,destination:"private-b-download.txt")
        _=await wait{a.finished && b.finished}
        check("private-download-owner-isolation",manager.downloads.visible(in:privateA).map(\.id)==[a.id] && manager.downloads.visible(in:privateB).map(\.id)==[b.id] && !manager.downloads.visible(in:session).contains{$0.id==a.id || $0.id==b.id})
        let modifiedAfter=(try? FileManager.default.attributesOfItem(atPath:manager.downloads.file.path))?[.modificationDate] as? Date
        check("private-download-does-not-write-history",modifiedBefore != nil && modifiedBefore==modifiedAfter && historyBefore == (try? Data(contentsOf:manager.downloads.file)))
        let disk=DownloadStore(root:root)
        check("private-download-not-persisted",!disk.items.contains{$0.id==a.id || $0.id==b.id})
        let privateActive=await start("slow-download.bin",in:privateA,destination:"private-active-download.bin")
        _=await wait{privateActive.fraction>0.01 || privateActive.finished}
        privateA.window?.performClose(nil)
        check("private-close-retires-active-download",privateActive.record.phase == .cancelled && !manager.downloads.items.contains{$0.id==privateActive.id})
        check("private-download-close-preserves-other-window",!manager.downloads.items.contains{$0.id==a.id} && manager.downloads.items.contains{$0.id==b.id})

        session.window?.makeKeyAndOrderFront(nil)
        let resumable=await start("slow-download.bin",in:session,destination:"resumed-download.bin")
        _=await wait{resumable.fraction>0.01 || resumable.finished}
        resumable.cancel(pause:true)
        _=await wait{!resumable.isActive}
        check("download-pause-has-resume-data",resumable.record.phase == .paused && resumable.canResume,resumable.status)
        check("download-paused-byte-metadata",(resumable.record.receivedBytes ?? 0)>0 && resumable.record.expectedBytes==8*1024*1024 && resumable.record.completed==nil,resumable.byteSummary ?? "No count")
        session.libraryPanel = .downloads
        try? await Task.sleep(for:.milliseconds(500))
        let capture="19-downloads-paused"
        try? capture.write(to:root.appendingPathComponent("capture-request"),atomically:true,encoding:.utf8)
        let captured=await wait{FileManager.default.fileExists(atPath:root.appendingPathComponent(capture+".capture-finished").path)}
        check("download-paused-ui-capture",captured && FileManager.default.fileExists(atPath:root.appendingPathComponent(capture+".png").path))
        session.libraryPanel=nil
        try? await Task.sleep(for:.milliseconds(500))
        resumable.resume(in:privateB)
        check("download-resume-rejects-private-context",resumable.record.phase == .paused && resumable.canResume)
        resumable.resume(in:session)
        _=await wait{resumable.finished}
        check("download-resume-completes",resumable.record.phase == .complete,resumable.status)
        let data=resumable.destination.flatMap{try? Data(contentsOf:$0)}
        check("download-resume-byte-integrity",data?.count==8*1024*1024 && data?.enumerated().allSatisfy{UInt8($0.offset%256)==$0.element} == true)
        check("download-resumed-final-byte-metadata",resumable.record.receivedBytes==8*1024*1024 && resumable.record.expectedBytes==8*1024*1024 && resumable.record.completed != nil,resumable.byteSummary ?? "No count")
        let cancelled=await start("slow-download.bin",in:session,destination:"cancelled-download.bin")
        _=await wait{cancelled.fraction>0.01 || cancelled.finished}
        cancelled.cancel(pause:true)
        _=await wait{!cancelled.isActive}
        check("download-cancel-fixture-paused",cancelled.canResume)
        cancelled.cancel()
        check("download-paused-cancel-discards-resume",cancelled.record.phase == .cancelled && !cancelled.canResume)
        check("download-paused-cancel-removes-disk-data",!FileManager.default.fileExists(atPath:manager.downloads.resumeDirectory.appendingPathComponent(cancelled.id.uuidString+".resume").path))
        privateB.window?.performClose(nil)
        check("private-download-close-clears-records",!manager.downloads.items.contains{$0.privateMode})
        session.window?.makeKeyAndOrderFront(nil)
        let shutdownPanel=await start("download.txt",in:session,destination:nil)
        let shutdownPanelVisible=await wait{session.window?.attachedSheet is NSSavePanel}
        let shutdownReady=await manager.downloads.prepareForTermination()
        check("download-shutdown-dismisses-destination-panel",shutdownPanelVisible && shutdownReady && session.window?.attachedSheet==nil && !shutdownPanel.isActive && shutdownPanel.destination==nil,shutdownPanel.status)
        let blockedRoot=root.appendingPathComponent("download-shutdown-blocked")
        do {
            try Data("fixture obstruction".utf8).write(to:blockedRoot)
            let blockedStore=DownloadStore(root:blockedRoot)
            let rejected=await blockedStore.prepareForTermination()
            check("download-shutdown-retains-app-on-save-failure",!rejected && blockedStore.error != nil)
            try FileManager.default.removeItem(at:blockedRoot)
            let recovered=await blockedStore.prepareForTermination()
            check("download-shutdown-retries-persistence",recovered && blockedStore.error==nil && FileManager.default.fileExists(atPath:blockedStore.file.path))
        } catch {check("download-shutdown-persistence-fixture",false,error.localizedDescription)}
        return results
    }
}
