import AppKit
import SwiftUI
import WebKit
import Metal

@MainActor final class Probe: NSObject, NSApplicationDelegate {
    var window: NSWindow!
    var webWindow:NSWindow!
    func applicationDidFinishLaunching(_ notification: Notification) {
        window = NSWindow(contentRect: NSRect(x: 100, y: 100, width: 1000, height: 700), styleMask: [.titled, .closable, .resizable, .miniaturizable], backing: .buffered, defer: false)
        window.title = "Serein — macOS 27 runtime probe"
        window.contentView = NSHostingView(rootView: VStack(spacing: 24) {
            Text("macOS 27 graphical execution").font(.largeTitle)
            Text(ProcessInfo.processInfo.operatingSystemVersionString)
            Button("Native Liquid Glass") { }.buttonStyle(.glass)
            Text("This is a platform experiment, not the browser UI.")
        }.frame(maxWidth: .infinity, maxHeight: .infinity))
        window.makeKeyAndOrderFront(nil)
        print("METAL_DEVICES \(MTLCopyAllDevices().map(\.name))")
        print("OS \(ProcessInfo.processInfo.operatingSystemVersionString)")
        webWindow=NSWindow(contentRect:NSRect(x:80,y:100,width:800,height:550),styleMask:[.titled,.closable,.resizable],backing:.buffered,defer:false)
        webWindow.title="System WebKit rendering witness — no hardened runtime"
        let web=WKWebView(frame:NSRect(x:0,y:0,width:800,height:550))
        webWindow.contentView=web;webWindow.makeKeyAndOrderFront(nil)
        web.loadHTMLString("<html><body style='font:32px system-ui;background:#dcefed;color:#173c38'><h1>WebKit rendering witness</h1><p>This is live HTML in a plain WKWebView.</p><div style='background:#b44735;width:300px;height:160px'></div></body></html>",baseURL:nil)
        fflush(stdout)
        NSApp.activate(ignoringOtherApps: true)
    }
}
@main struct Main {
    @MainActor static func main() {
        let app = NSApplication.shared
        app.setActivationPolicy(.regular)
        let delegate = Probe()
        app.delegate = delegate
        app.run()
    }
}
