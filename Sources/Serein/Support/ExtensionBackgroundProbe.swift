import Foundation
import WebKit

/// A broken extension must not prevent independent runtime scenarios from running.
@MainActor enum ExtensionBackgroundProbe {
    private final class Reply {
        var continuation:CheckedContinuation<String?,Never>?
        var deadline:Task<Void,Never>?
        init(_ continuation:CheckedContinuation<String?,Never>){self.continuation=continuation}
        func finish(_ failure:String?) {
            guard let continuation else{return}
            self.continuation=nil;deadline?.cancel();deadline=nil
            continuation.resume(returning:failure)
        }
    }
    static func failure(for context:WKWebExtensionContext) async->String? {
        await withCheckedContinuation {continuation in
            let reply=Reply(continuation)
            reply.deadline=Task {
                try? await Task.sleep(for:.seconds(5))
                guard !Task.isCancelled else{return}
                reply.finish("Public background-load completion did not return within five seconds")
            }
            context.loadBackgroundContent {error in reply.finish(error?.localizedDescription)}
        }
    }
}
