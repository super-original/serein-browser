import AppKit
import SwiftUI

@MainActor final class Probe: NSObject, NSApplicationDelegate {
    var window: NSWindow!
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
        NSApp.activate(ignoringOtherApps: true)
    }
}
let app = NSApplication.shared
app.setActivationPolicy(.regular)
let delegate = Probe()
app.delegate = delegate
app.run()
