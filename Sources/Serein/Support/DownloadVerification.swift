import WebKit
import Foundation
import SereinCore

/// Uses the production store/delegate with deterministic destination selection.
/// This suite does not claim native Save-panel or cross-launch resume coverage.
@MainActor enum DownloadVerification {
    static func run(manager:BrowserManager,session:BrowserSession,root:URL) async -> [RuntimeVerification.Result] {
        var results:[RuntimeVerification.Result]=[]
        func check(_ name:String,_ passed:Bool,_ detail:String="") {results.append(.init(name:name,passed:passed,detail:detail))}
        func wait(_ condition:@MainActor ()->Bool) async -> Bool {
            for _ in 0..<150 {if condition(){return true};try? await Task.sleep(for:.milliseconds(100))};return false
        }
        func start(_ name:String,in owner:BrowserSession,destination:String) async -> DownloadItem {
            await withCheckedContinuation {continuation in
                owner.current!.webView.startDownload(using:URLRequest(url:URL(string:"http://127.0.0.1:8765/"+name)!)) {download in
                    continuation.resume(returning:manager.downloads.add(download,in:owner,destination:root.appendingPathComponent(destination)))
                }
            }
        }
        let item=await start("download.txt",in:session,destination:"download-result.txt")
        let completed=await wait{item.finished}
        check("download-production-completes",completed && item.record.phase == .complete,item.status)
        check("download-content",item.destination.flatMap{try? String(contentsOf:$0,encoding:.utf8)} == "Serein deterministic download fixture v1.\n")
        let restored=DownloadStore(root:root)
        check("download-history-restores",restored.items.contains{$0.id==item.id && $0.record.phase == .complete && $0.destination==item.destination},restored.error ?? "")

        let privateA=manager.newWindow(isPrivate:true),privateB=manager.newWindow(isPrivate:true)
        let a=await start("download.txt",in:privateA,destination:"private-a-download.txt")
        let b=await start("download.txt",in:privateB,destination:"private-b-download.txt")
        _=await wait{a.finished && b.finished}
        check("private-download-owner-isolation",manager.downloads.visible(in:privateA).map(\.id)==[a.id] && manager.downloads.visible(in:privateB).map(\.id)==[b.id] && !manager.downloads.visible(in:session).contains{$0.id==a.id || $0.id==b.id})
        let disk=DownloadStore(root:root)
        check("private-download-not-persisted",!disk.items.contains{$0.id==a.id || $0.id==b.id})
        privateA.window?.performClose(nil)
        check("private-download-close-preserves-other-window",!manager.downloads.items.contains{$0.id==a.id} && manager.downloads.items.contains{$0.id==b.id})

        session.window?.makeKeyAndOrderFront(nil)
        let resumable=await start("slow-download.bin",in:session,destination:"resumed-download.bin")
        _=await wait{resumable.fraction>0.01 || resumable.finished}
        resumable.cancel(pause:true)
        _=await wait{!resumable.isActive}
        check("download-pause-has-resume-data",resumable.record.phase == .paused && resumable.canResume,resumable.status)
        resumable.resume(in:privateB)
        check("download-resume-rejects-private-context",resumable.record.phase == .paused && resumable.canResume)
        resumable.resume(in:session)
        _=await wait{resumable.finished}
        check("download-resume-completes",resumable.record.phase == .complete,resumable.status)
        let data=resumable.destination.flatMap{try? Data(contentsOf:$0)}
        check("download-resume-byte-integrity",data?.count==8*1024*1024 && data?.enumerated().allSatisfy{UInt8($0.offset%256)==$0.element} == true)
        privateB.window?.performClose(nil)
        check("private-download-close-clears-records",!manager.downloads.items.contains{$0.privateMode})
        session.window?.makeKeyAndOrderFront(nil)
        return results
    }
}
