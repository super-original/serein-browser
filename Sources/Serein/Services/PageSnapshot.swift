import AppKit
import WebKit
import UniformTypeIdentifiers

/// A user-requested image of one page viewport, never a desktop capture.
@MainActor enum PageSnapshot {
    enum Failure:LocalizedError {
        case unavailable,changed,timedOut,encoding
        var errorDescription:String? {
            switch self {
            case .unavailable:return "Select a loaded page before saving its screenshot."
            case .changed:return "The page changed while its screenshot was being prepared. Try again."
            case .timedOut:return "The page did not finish preparing its screenshot. Try again."
            case .encoding:return "The page screenshot could not be encoded as a PNG image."
            }
        }
    }
    struct Capture {
        let png:Data
        let document:UUID
        let runtime:TabRuntime
        let view:WKWebView
        func isCurrent(in session:BrowserSession)->Bool {
            guard let window=session.window,window.isVisible,
                  session.manager?.windows.contains(where:{$0.session===session})==true else{return false}
            return session.current === runtime && session.runtimes[runtime.id] === runtime &&
            runtime.documentID==document && runtime.loadedWebView === view &&
            view.window === window && !runtime.isLoading && !view.isLoading && !runtime.crashed && runtime.failure==nil
        }
    }
    static func available(in session:BrowserSession)->Bool {
        guard !session.savingPageSnapshot,session.window?.isVisible==true,session.window?.attachedSheet==nil,
              let runtime=session.current,let view=runtime.loadedWebView,
              view.window != nil,view.window === session.window,!runtime.isLoading,!view.isLoading,
              !runtime.crashed,runtime.failure==nil,view.url != nil,
              view.bounds.width>0,view.bounds.height>0 else{return false}
        return true
    }
    private final class Reply {
        var continuation:CheckedContinuation<NSImage,any Error>?
        var deadline:Task<Void,Never>?
        init(_ continuation:CheckedContinuation<NSImage,any Error>){self.continuation=continuation}
        func finish(_ result:Result<NSImage,any Error>) {
            guard let continuation else{return}
            self.continuation=nil;deadline?.cancel();deadline=nil
            continuation.resume(with:result)
        }
    }
    static func capture(in session:BrowserSession) async throws->Capture {
        guard let runtime=session.current,let view=runtime.loadedWebView,
              view.window != nil,view.window === session.window,!runtime.isLoading,!view.isLoading,
              !runtime.crashed,runtime.failure==nil,view.url != nil,view.bounds.width>0,view.bounds.height>0 else{throw Failure.unavailable}
        let document=runtime.documentID
        let configuration=WKSnapshotConfiguration();configuration.rect=view.bounds
        let image=try await withCheckedThrowingContinuation { (continuation:CheckedContinuation<NSImage,any Error>) in
            let reply=Reply(continuation)
            reply.deadline=Task {
                try? await Task.sleep(for:.seconds(10))
                if !Task.isCancelled{reply.finish(.failure(Failure.timedOut))}
            }
            view.takeSnapshot(with:configuration) {image,error in
                if let image{reply.finish(.success(image))}
                else{reply.finish(.failure(error ?? Failure.encoding))}
            }
        }
        guard let tiff=image.tiffRepresentation,let bitmap=NSBitmapImageRep(data:tiff),
              let png=bitmap.representation(using:.png,properties:[:]) else{throw Failure.encoding}
        let result=Capture(png:png,document:document,runtime:runtime,view:view)
        guard result.isCurrent(in:session) else{throw Failure.changed}
        return result
    }
    /// Returns nil on cancellation; no temporary image or history record is written.
    static func save(in session:BrowserSession) async throws->URL? {
        guard available(in:session),let window=session.window else{throw Failure.unavailable}
        session.savingPageSnapshot=true;defer{session.savingPageSnapshot=false}
        let capture=try await capture(in:session)
        guard window.attachedSheet==nil else{throw Failure.unavailable}
        let panel=NSSavePanel();panel.allowedContentTypes=[.png]
        panel.nameFieldStringValue="Page Screenshot.png"
        panel.title="Save Page Screenshot"
        panel.message="Save the visible area of this page as a PNG image." + (session.state.isPrivate ? " This saves private page content to disk." : "")
        let response=await withCheckedContinuation {continuation in
            panel.beginSheetModal(for:window){continuation.resume(returning:$0)}
        }
        guard response == .OK,let url=panel.url else{return nil}
        guard capture.isCurrent(in:session) else{throw Failure.changed}
        let access=url.startAccessingSecurityScopedResource();defer{if access{url.stopAccessingSecurityScopedResource()}}
        try capture.png.write(to:url,options:.atomic)
        return url
    }
}
