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
        manager=BrowserManager(root:root)
        manager.menu.install()
        manager.restore()
        NSApp.activate(ignoringOtherApps:true)
        Task {await manager.extensions.restore()}
        if args.contains("--integration-test") {Task {await RuntimeVerification.run(manager:manager,root:root)}}
    }
    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
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
