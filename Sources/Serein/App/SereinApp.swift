import AppKit
import SwiftUI

@main enum SereinApp {
    @MainActor static func main() {
        let app=NSApplication.shared
        app.setActivationPolicy(.regular)
        let delegate=AppDelegate();app.delegate=delegate
        withExtendedLifetime(delegate){app.run()}
    }
}
@MainActor final class AppDelegate: NSObject, NSApplicationDelegate {
    var manager: BrowserManager!
    func applicationDidFinishLaunching(_ notification: Notification) {
        let args=ProcessInfo.processInfo.arguments
        let testRoot=args.firstIndex(of:"--test-root").flatMap{args.indices.contains($0+1) ? URL(fileURLWithPath:args[$0+1]) : nil}
        let root=testRoot ?? FileManager.default.urls(for:.applicationSupportDirectory,in:.userDomainMask)[0].appendingPathComponent("Serein",isDirectory:true)
        if args.contains("--native-bridge-test"),testRoot != nil {
            try? FileManager.default.createDirectory(at:root,withIntermediateDirectories:true)
            Task {
                let results=await NativeBridgeVerification.run(root:root)
                try? JSONEncoder().encode(results).write(to:root.appendingPathComponent("results.json"),options:.atomic)
                NSApp.terminate(nil)
            }
            return
        }
        manager=BrowserManager(root:root)
        manager.menu.install()
        manager.restore()
        manager.tabSuspension.start()
        NSApp.activate(ignoringOtherApps:true)
        if args.contains("--crash-recovery-test"),testRoot != nil {
            Task {await CrashRecoveryVerification.run(manager:manager,root:root)}
            return
        }
        if args.contains("--quit-consent-test"),testRoot != nil {
            if args.contains("--native-host-quit-test") {
                Task {
                    do {
                        try await NativeHostVerification.prepareQuit(manager:manager,root:root)
                        QuitConsentVerification.run(manager:manager,root:root)
                    } catch {
                        try? error.localizedDescription.write(to:root.appendingPathComponent("native-setup-error"),atomically:true,encoding:.utf8)
                        NSApp.terminate(nil)
                    }
                }
            } else {QuitConsentVerification.run(manager:manager,root:root)}
            return
        }
        if args.contains("--history-restart-prepare") || args.contains("--history-restart-resume") || args.contains("--history-restart-fallback"),testRoot != nil {
            Task {await HistoryRestartVerification.run(manager:manager,root:root,prepare:args.contains("--history-restart-prepare"),fallback:args.contains("--history-restart-fallback"))}
            return
        }
        if args.contains("--download-restart-prepare") || args.contains("--download-restart-resume"),testRoot != nil {
            Task {await DownloadRestartVerification.run(manager:manager,root:root,prepare:args.contains("--download-restart-prepare"))}
            return
        }
        if let index=args.firstIndex(of:"--fullscreen-probe"),args.indices.contains(index+1),testRoot != nil {
            Task {
                let results=await FullscreenVerification.isolated(manager:manager,root:root,probe:args[index+1])
                try? JSONEncoder().encode(results).write(to:root.appendingPathComponent("results.json"),options:.atomic)
                NSApp.terminate(nil)
            }
            return
        }
        if let index=args.firstIndex(of:"--extension-origin-probe"),args.indices.contains(index+1),testRoot != nil {
            Task {
                let results:[RuntimeVerification.Result]
                if args[index+1]=="real" {results=await RealContentBlockerVerification.run(firefoxOrigin:true)}
                else {results=await ExtensionOriginVerification.run(manager:manager,root:root)}
                try? JSONEncoder().encode(results).write(to:root.appendingPathComponent("results.json"),options:.atomic)
                NSApp.terminate(nil)
            }
            return
        }
        Task {await manager.extensions.restore()}
        if args.contains("--integration-test"),testRoot != nil {Task {await RuntimeVerification.run(manager:manager,root:root)}}
    }
    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        if let session=manager?.windows.map(\.session).first(where:{$0.runtimes.values.contains{$0.hasUserEdits}}) {
            let documents=Dictionary(uniqueKeysWithValues:manager.windows.map{($0.session.state.id,$0.session.closeConsentSnapshot)})
            session.confirm("Quit Serein?",detail:"Open pages have edits. Unsaved changes may be lost.",yes:"Quit") {allowed in
                let current=Dictionary(uniqueKeysWithValues:self.manager.windows.map{($0.session.state.id,$0.session.closeConsentSnapshot)})
                let approved=allowed && current==documents
                if approved {
                    switch self.finishTermination(sender) {
                    case .terminateNow:sender.reply(toApplicationShouldTerminate:true)
                    case .terminateCancel:sender.reply(toApplicationShouldTerminate:false)
                    case .terminateLater:break
                    @unknown default:sender.reply(toApplicationShouldTerminate:false)
                    }
                } else {sender.reply(toApplicationShouldTerminate:false)}
            }
            return .terminateLater
        }
        return finishTermination(sender)
    }
    private func finishTermination(_ sender:NSApplication)->NSApplication.TerminateReply {
        guard let manager else{return .terminateNow}
        guard manager.extensions.nativeMessaging.hasConnections || manager.downloads.items.contains(where: {$0.isActive || $0.canResume}) else {
            guard manager.saveNow() else {
                manager.active?.error=manager.restorationError
                return .terminateCancel
            }
            return .terminateNow
        }
        let documents=Dictionary(uniqueKeysWithValues:manager.windows.map{($0.session.state.id,$0.session.closeConsentSnapshot)})
        Task {
            await manager.extensions.nativeMessaging.shutdown()
            let downloadsReady=await manager.downloads.prepareForTermination()
            let current=Dictionary(uniqueKeysWithValues:manager.windows.map{($0.session.state.id,$0.session.closeConsentSnapshot)})
            let unchanged=current==documents && downloadsReady
            let saved=unchanged && manager.saveNow()
            if !saved {
                manager.extensions.nativeMessaging.resumeAcceptingConnections()
                manager.active?.error = !downloadsReady ? manager.downloads.error : !unchanged ? "Open pages changed while downloads and native applications were closing. Review your work and quit again." : manager.restorationError
            }
            sender.reply(toApplicationShouldTerminate:saved)
        }
        return .terminateLater
    }
    func applicationShouldHandleReopen(_ sender: NSApplication,hasVisibleWindows flag: Bool) -> Bool {
        if !flag {manager?.newWindow()};return true
    }
    func application(_ application: NSApplication,open urls: [URL]) {
        if manager?.active==nil {manager?.newWindow()}
        for url in urls where ["https","http"].contains(url.scheme ?? "") {manager?.active?.newTab(url:url.absoluteString)}
    }
}
