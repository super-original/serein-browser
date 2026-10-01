import AppKit
import WebKit
import SereinCore

/// Two independently launched processes exercise persisted opaque WebKit data.
@MainActor enum DownloadRestartVerification {
    static func run(manager:BrowserManager,root:URL,prepare:Bool) async {
        var results:[RuntimeVerification.Result]=[]
        func check(_ name:String,_ passed:Bool,_ detail:String="") {results.append(.init(name:name,passed:passed,detail:detail))}
        func wait(_ condition:@MainActor ()->Bool) async {
            for _ in 0..<250 {if condition(){return};try? await Task.sleep(for:.milliseconds(100))}
        }
        guard let session=manager.active else{return}
        if prepare {
            func start(in owner:BrowserSession,name:String,pause:Bool=true) async -> DownloadItem {
                let item:DownloadItem=await withCheckedContinuation {continuation in
                    owner.current!.webView.startDownload(using:URLRequest(url:URL(string:"http://127.0.0.1:8765/slow-download.bin")!)) {download in
                        continuation.resume(returning:manager.downloads.add(download,in:owner,destination:root.appendingPathComponent(name)))
                    }
                }
                await wait{item.fraction>0.01 || item.finished}
                if pause {item.cancel(pause:true);await wait{!item.isActive}}
                return item
            }
            let normal=await start(in:session,name:"restart-download.bin")
            check("restart-prepare-normal-paused",normal.canResume && normal.record.phase == .paused,normal.status)
            let privateSession=manager.newWindow(isPrivate:true)
            let privateItem=await start(in:privateSession,name:"private-restart.bin",pause:false)
            check("restart-prepare-private-active",privateItem.isActive && privateItem.fraction>0 && privateItem.fraction<1,privateItem.status)
            let files=(try? FileManager.default.contentsOfDirectory(atPath:manager.downloads.resumeDirectory.path)) ?? []
            check("restart-private-resume-not-written",files==[normal.id.uuidString+".resume"],files.joined(separator:","))
            let mode=(try? FileManager.default.attributesOfItem(atPath:manager.downloads.resumeDirectory.path)[.posixPermissions]) as? NSNumber
            let fileMode=(try? FileManager.default.attributesOfItem(atPath:manager.downloads.resumeDirectory.appendingPathComponent(normal.id.uuidString+".resume").path)[.posixPermissions]) as? NSNumber
            check("restart-resume-owner-only",mode?.intValue==0o700 && fileMode?.intValue==0o600)
            let live=await start(in:session,name:"quit-download.bin",pause:false)
            check("restart-quit-starts-with-active-download",live.isActive && live.fraction>0 && live.fraction<1,live.status)
            check("restart-normal-identifiers-persisted",normal.record.browserIdentifier==1 && live.record.browserIdentifier==2)
            check("restart-private-has-no-browser-identifier",privateItem.record.browserIdentifier==nil)
            let identifiers=[normal.id.uuidString:normal.record.browserIdentifier ?? -1,live.id.uuidString:live.record.browserIdentifier ?? -1]
            try? JSONEncoder().encode(identifiers).write(to:root.appendingPathComponent("restart-download-identifiers.json"),options:.atomic)
        } else {
            check("restart-private-history-excluded",manager.downloads.items.count==2 && manager.downloads.items.allSatisfy{!$0.privateMode})
            let identifiers=(try? JSONDecoder().decode([String:Int64].self,from:Data(contentsOf:root.appendingPathComponent("restart-download-identifiers.json")))) ?? [:]
            check("restart-identifiers-survive-process-exit",identifiers.count==2 && manager.downloads.items.allSatisfy{identifiers[$0.id.uuidString]==$0.record.browserIdentifier})
            for item in manager.downloads.items {
                let prefix=item.name=="quit-download.bin" ? "quit-" : "manual-"
                check(prefix+"restart-restores-resumable-item",item.canResume && item.record.phase == .paused,item.status)
                item.resume(in:session)
                await wait{item.finished}
                check(prefix+"restart-resume-completes",item.record.phase == .complete,item.status)
                let data=item.destination.flatMap{try? Data(contentsOf:$0)}
                check(prefix+"restart-resume-byte-integrity",data?.count==8*1024*1024 && data?.enumerated().allSatisfy{UInt8($0.offset%256)==$0.element} == true)
            }
            let files=(try? FileManager.default.contentsOfDirectory(atPath:manager.downloads.resumeDirectory.path)) ?? []
            check("restart-completion-discards-resume-data",files.isEmpty)
            check("restart-resume-keeps-identifiers",identifiers.count==2 && manager.downloads.items.allSatisfy{identifiers[$0.id.uuidString]==$0.record.browserIdentifier})
        }
        try? JSONEncoder().encode(results).write(to:root.appendingPathComponent(prepare ? "prepare-results.json" : "resume-results.json"),options:.atomic)
        // Return from this Swift task before the supervisor sends real Command-Q.
        // Calling terminateLater from the task being awaited can trap the fixture
        // inside AppKit's modal termination loop and prevent shutdown work running.
    }
}
