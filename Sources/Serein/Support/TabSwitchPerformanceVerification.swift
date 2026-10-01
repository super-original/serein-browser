import AppKit
import WebKit

/// Measures native attachment + a document identity roundtrip, not rendered frames.
@MainActor enum TabSwitchPerformanceVerification {
    private struct Sample:Codable {
        let ordinal:Int
        let tab:Int
        let milliseconds:Double
        let attached:Bool
        let documentMatched:Bool
    }
    private struct Report:Codable {
        let os:String
        let note:String
        let samples:[Sample]
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
    private static func matches(_ view:WKWebView,index:Int) async->Bool {
        await withCheckedContinuation {continuation in
            let reply=Reply(continuation)
            reply.deadline=Task {try? await Task.sleep(for:.seconds(2));guard !Task.isCancelled else{return};reply.finish(false)}
            view.evaluateJavaScript("document.title==='Field Notes' && new URL(location.href).searchParams.get('switch-benchmark')==='\(index)'") {value,error in
                reply.finish(error==nil && value as? Bool==true)
            }
        }
    }
    static func run(manager:BrowserManager,root:URL) async->[RuntimeVerification.Result] {
        var results:[RuntimeVerification.Result]=[]
        func check(_ name:String,_ passed:Bool,_ detail:String="") {results.append(.init(name:"tab-switch-performance-"+name,passed:passed,detail:detail))}
        func wait(_ condition:@MainActor ()->Bool) async->Bool {
            for _ in 0..<200 {if condition(){return true};try? await Task.sleep(for:.milliseconds(10))};return false
        }
        let session=manager.newWindow()
        defer{session.window?.close()}
        var ids:[UUID]=[],ready=true
        AppMemoryProbe.record("tab-switch-benchmark-before")
        for index in 0..<4 {
            let url="http://127.0.0.1:8765/index.html?switch-benchmark=\(index)"
            let id=index==0 ? session.state.selectedTabID! : session.newTab()
            session.navigate(url,ask:false);ids.append(id)
            let view=session.runtime(id).webView
            let loaded=await wait{view.url?.absoluteString==url && !view.isLoading && view.title=="Field Notes"}
            ready=ready && loaded
        }
        check("four-tabs-loaded",ready)
        guard ready else{return results}
        var samples:[Sample]=[]
        let clock=ContinuousClock()
        for ordinal in 0..<24 {
            let index=[0,2,1,3][ordinal%4],started=clock.now
            session.select(ids[index])
            let view=session.runtime(ids[index]).webView
            let attached=await wait{view.window===session.window && view.bounds.width>200}
            let document=await matches(view,index:index)
            let duration=started.duration(to:clock.now).components
            let milliseconds=Double(duration.seconds)*1000+Double(duration.attoseconds)/1e15
            samples.append(Sample(ordinal:ordinal,tab:index,milliseconds:milliseconds,attached:attached,documentMatched:document))
        }
        check("all-switches-attach-correct-document",samples.count==24 && samples.allSatisfy{$0.attached && $0.documentMatched})
        let sorted=samples.map(\.milliseconds).sorted()
        let summary="24 warm switches, 4 local tabs; median \((sorted[11]+sorted[12])/2) ms, nearest-rank p95 \(sorted[22]) ms. Includes native attachment polling and script roundtrip; not visible-frame latency."
        do {
            let report=Report(os:ProcessInfo.processInfo.operatingSystemVersionString,note:"Standard free ARM64 macOS 27 runner. Four preloaded original local pages; cyclic 0,2,1,3 order repeated six times. Ten-millisecond attachment polling and a two-second script deadline. Existing browser workload stays open. Desktop rendering is separately failing; no startup, scrolling, energy or physical-Mac claim.",samples:samples)
            try JSONEncoder().encode(report).write(to:root.appendingPathComponent("tab-switch-performance.json"),options:.atomic)
            check("measurement-written",true,summary)
        } catch {check("measurement-written",false,error.localizedDescription)}
        AppMemoryProbe.record("tab-switch-benchmark-after")
        return results
    }
}
