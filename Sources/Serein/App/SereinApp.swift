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
        NSApp.activate(ignoringOtherApps:true)
        if args.contains("--quit-consent-test"),testRoot != nil {
            Task {await QuitConsentVerification.run(manager:manager,root:root)}
            return
        }
        Task {await manager.extensions.restore()}
        if args.contains("--integration-test") {Task {await RuntimeVerification.run(manager:manager,root:root)}}
    }
    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        if let session=manager?.windows.map(\.session).first(where:{$0.runtimes.values.contains{$0.hasUserEdits}}) {
            let documents=Dictionary(uniqueKeysWithValues:manager.windows.map{($0.session.state.id,$0.session.closeConsentSnapshot)})
            session.confirm("Quit Serein?",detail:"Open pages have edits. Unsaved changes may be lost.",yes:"Quit") {allowed in
                let current=Dictionary(uniqueKeysWithValues:self.manager.windows.map{($0.session.state.id,$0.session.closeConsentSnapshot)})
                let approved=allowed && current==documents
                if approved {self.manager.saveNow()}
                sender.reply(toApplicationShouldTerminate:approved)
            }
            return .terminateLater
        }
        manager?.saveNow();return .terminateNow
    }
    func applicationShouldHandleReopen(_ sender: NSApplication,hasVisibleWindows flag: Bool) -> Bool {
        if !flag {manager?.newWindow()};return true
    }
    func application(_ application: NSApplication,open urls: [URL]) {
        if manager?.active==nil {manager?.newWindow()}
        for url in urls where ["https","http"].contains(url.scheme ?? "") {manager?.active?.newTab(url:url.absoluteString)}
    }
}
