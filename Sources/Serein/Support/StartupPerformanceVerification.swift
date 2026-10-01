import AppKit
import WebKit

/// Actual process launches through BrowserManager.restore, never a frame-rendering metric.
@MainActor enum StartupPerformanceVerification {
    private static let page="http://127.0.0.1:8765/index.html?startup-benchmark=restored"
    private struct Report:Codable {
        let mode:String
        let passed:Bool
        let entryToReadinessMilliseconds:Double
        let detail:String
        let os:String
    }
    private final class Reply {
        var continuation:CheckedContinuation<Bool,Never>?
        var deadline:Task<Void,Never>?
        init(_ continuation:CheckedContinuation<Bool,Never>){self.continuation=continuation}
        func finish(_ value:Bool) {
            guard let continuation else{return}
            self.continuation=nil;deadline?.cancel();deadline=nil;continuation.resume(returning:value)
        }
    }
    private static func documentMatches(_ view:WKWebView) async->Bool {
        await withCheckedContinuation {continuation in
            let reply=Reply(continuation)
            reply.deadline=Task {try? await Task.sleep(for:.seconds(2));guard !Task.isCancelled else{return};reply.finish(false)}
            view.evaluateJavaScript("document.title==='Field Notes' && new URL(location.href).searchParams.get('startup-benchmark')==='restored'") {value,error in
                reply.finish(error==nil && value as? Bool==true)
            }
        }
    }
    static func run(manager:BrowserManager,root:URL,mode:String,entry:TimeInterval) async {
        guard ["fresh","seed","restore"].contains(mode),let session=manager.active else{return}
        if mode=="seed" {session.navigate(page,ask:false)}
        var ready=false
        for _ in 0..<1500 {
            let attached=session.window?.isVisible==true && (session.window?.contentView?.bounds.width ?? 0)>200
            if mode=="fresh" {
                ready=attached && manager.windows.count==1 && session.state.tabs.count==1 && session.state.tabs.first?.url=="about:blank"
            } else if let view=session.current?.loadedWebView {
                ready=attached && view.window===session.window && view.bounds.width>200 && !view.isLoading && view.url?.absoluteString==page && view.title=="Field Notes"
            }
            if ready {break}
            try? await Task.sleep(for:.milliseconds(10))
        }
        ready=ready && manager.restorationError==nil && manager.windows.count==1 && session.state.tabs.count==1
        if ready && mode != "fresh",let view=session.current?.loadedWebView {ready=await documentMatches(view)}
        let milliseconds=(ProcessInfo.processInfo.systemUptime-entry)*1000
        if mode=="seed" {ready=manager.saveNow() && ready}
        let report=Report(mode:mode,passed:ready,entryToReadinessMilliseconds:milliseconds,
            detail:"Fresh: one visible native window with its default blank tab. Restore: production-restored local page attached and matching a bounded JavaScript identity check. Ten-millisecond polling; no visible-frame, cold OS-cache, LaunchServices, or physical-Mac claim.",
            os:ProcessInfo.processInfo.operatingSystemVersionString)
        try? JSONEncoder().encode(report).write(to:root.appendingPathComponent("startup-ready.json"),options:.atomic)
        NSApp.terminate(nil)
    }
}
