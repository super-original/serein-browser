import AppKit
import WebKit

/// Opt-in idle unloading. Missing media information always keeps a page loaded.
@MainActor final class TabSuspensionController {
    weak var manager:BrowserManager?
    private var task:Task<Void,Never>?
    private var sweeping=false
    private let mediaState:@MainActor (WKWebView) async->WKMediaPlaybackState?
    init(manager:BrowserManager,mediaState:@escaping @MainActor (WKWebView) async->WKMediaPlaybackState? = {await TabSuspensionController.playbackState($0)}) {
        self.manager=manager;self.mediaState=mediaState
    }
    deinit{task?.cancel()}
    func start() {
        guard task==nil else{return}
        task=Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for:.seconds(60))
                guard !Task.isCancelled else{return}
                await self?.sweep()
            }
        }
    }
    private func eligible(_ runtime:TabRuntime,in session:BrowserSession)->Bool {
        guard let manager,manager.windows.contains(where:{$0.session===session}),
              session.runtimes[runtime.id] === runtime,!session.state.isPrivate,
              session.window?.attachedSheet==nil,session.libraryPanel==nil,
              !manager.downloads.items.contains(where:{$0.isActive}),
              let tab=session.state.tabs.first(where:{$0.id==runtime.id}),tab.kind == .regular,
              tab.glanceParentID==nil,session.state.glance(for:tab.id)==nil,
              session.canUnload(tab.id),!runtime.hasUserEdits,!runtime.crashed,
              runtime.failure==nil,!runtime.hasPendingExtensionReload,
              let view=runtime.loadedWebView,view.window==nil,!view.isLoading,
              ["http","https"].contains(view.url?.scheme?.lowercased() ?? ""),
              view.cameraCaptureState == .none,view.microphoneCaptureState == .none else{return false}
        return true
    }
    @discardableResult func sweep(now:ContinuousClock.Instant=ContinuousClock().now,idleMinutes:Int?=nil) async->Int {
        let minutes=idleMinutes ?? UserDefaults.standard.integer(forKey:"idleTabUnloadMinutes")
        guard [15,30,60].contains(minutes),!sweeping,let manager else{return 0}
        sweeping=true;defer{sweeping=false}
        var unloaded=0
        for session in manager.windows.map(\.session) {
            for runtime in Array(session.runtimes.values) {
                guard eligible(runtime,in:session) else{runtime.noteActivity(at:now);continue}
                let activity=runtime.lastActivity,document=runtime.documentID
                guard activity.duration(to:now) >= .seconds(minutes*60),
                      let view=runtime.loadedWebView else{continue}
                let playback=await mediaState(view)
                guard playback == WKMediaPlaybackState.none else{runtime.noteActivity(at:now);continue}
                // Navigation, activation, edits, downloads and view replacement can
                // all occur while WebKit answers the asynchronous media request.
                guard (idleMinutes != nil || UserDefaults.standard.integer(forKey:"idleTabUnloadMinutes")==minutes),
                      eligible(runtime,in:session),runtime.documentID==document,
                      runtime.lastActivity==activity,runtime.loadedWebView === view else{continue}
                runtime.suspend();unloaded += 1
            }
        }
        return unloaded
    }
    private final class PlaybackReply {
        var continuation:CheckedContinuation<WKMediaPlaybackState?,Never>?
        var deadline:Task<Void,Never>?
        init(_ continuation:CheckedContinuation<WKMediaPlaybackState?,Never>){self.continuation=continuation}
        func finish(_ state:WKMediaPlaybackState?) {
            guard let continuation else{return}
            self.continuation=nil;deadline?.cancel();deadline=nil
            continuation.resume(returning:state)
        }
    }
    static func playbackState(_ view:WKWebView) async->WKMediaPlaybackState? {
        await withCheckedContinuation {continuation in
            let reply=PlaybackReply(continuation)
            reply.deadline=Task {
                try? await Task.sleep(for:.seconds(2))
                guard !Task.isCancelled else{return}
                reply.finish(nil)
            }
            view.requestMediaPlaybackState {reply.finish($0)}
        }
    }
}
