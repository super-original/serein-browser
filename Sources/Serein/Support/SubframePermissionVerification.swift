import AppKit
import WebKit

/// Real frame metadata and production delegate; simulated media request/response.
/// No physical capture or OS device permission is asserted by this fixture.
@MainActor enum SubframePermissionVerification {
    private final class Frames:NSObject,WKScriptMessageHandler {
        var frames:[WKFrameInfo]=[]
        func userContentController(_ userContentController:WKUserContentController,didReceive message:WKScriptMessage) {
            if !message.frameInfo.isMainFrame {frames.append(message.frameInfo)}
        }
    }
    private final class Response {var value:WKPermissionDecision?}
    static func run(manager:BrowserManager,root:URL) async->[RuntimeVerification.Result] {
        var results:[RuntimeVerification.Result]=[]
        func check(_ name:String,_ passed:Bool,_ detail:String=""){results.append(.init(name:"subframe-permission-"+name,passed:passed,detail:detail))}
        func wait(_ condition:@MainActor ()->Bool) async {for _ in 0..<120 {if condition(){return};try? await Task.sleep(for:.milliseconds(50))}}
        let session=manager.newWindow(isPrivate:true)
        defer{session.window?.close()}
        guard let runtime=session.current,let window=session.window else{return results}
        let view=runtime.webView,frames=Frames(),world=WKContentWorld.world(name:"SereinPermissionFrameProbe")
        view.configuration.userContentController.add(frames,contentWorld:world,name:"permissionFrame")
        view.configuration.userContentController.addUserScript(WKUserScript(source:"window.webkit.messageHandlers.permissionFrame.postMessage(location.href);",injectionTime:.atDocumentEnd,forMainFrameOnly:false,in:world))
        defer{view.configuration.userContentController.removeScriptMessageHandler(forName:"permissionFrame",contentWorld:world)}
        runtime.load(URL(string:"http://127.0.0.1:8765/permission-frames.html")!)
        await wait{view.title=="Permission frame fixture" && !view.isLoading && !frames.frames.isEmpty}
        guard let initial=frames.frames.last else{check("setup",false,"No real child-frame metadata");return results}
        check("cross-origin-frame-setup",initial.securityOrigin.host=="localhost" && view.url?.host=="127.0.0.1" && !initial.isMainFrame)
        let topDocument=runtime.documentID
        func request(_ frame:WKFrameInfo)->Response {
            let response=Response()
            runtime.webView(view,requestMediaCapturePermissionFor:frame.securityOrigin,initiatedByFrame:frame,type:.camera) {response.value=$0}
            return response
        }
        let first=request(initial)
        await wait{window.attachedSheet != nil || first.value != nil}
        check("native-sheet-for-frame",window.attachedSheet != nil && first.value==nil)
        let sheet=window.attachedSheet
        try? "52-subframe-permission".write(to:root.appendingPathComponent("capture-request"),atomically:true,encoding:.utf8)
        await wait{FileManager.default.fileExists(atPath:root.appendingPathComponent("52-subframe-permission.capture-finished").path)}
        _=try? await view.evaluateJavaScript("document.querySelector('iframe').src='http://localhost:8765/second.html?permission-child=navigated'")
        await wait{frames.frames.last?.request.url?.query=="permission-child=navigated"}
        if let sheet{window.endSheet(sheet,returnCode:.alertThirdButtonReturn)}
        await wait{first.value != nil && window.attachedSheet==nil}
        check("changed-child-denies-stale-consent",sheet != nil && first.value == .deny && runtime.documentID==topDocument,"Parent document is unchanged; only the requesting child navigated")
        check("stale-child-grant-not-saved",session.sitePermissions.policy.records.isEmpty)
        await wait{!view.isLoading}
        guard let current=frames.frames.last else{return results}
        let once=request(current)
        await wait{window.attachedSheet != nil || once.value != nil}
        let onceSheet=window.attachedSheet
        if let onceSheet{window.endSheet(onceSheet,returnCode:.alertFirstButtonReturn)}
        await wait{once.value != nil && window.attachedSheet==nil}
        check("unchanged-child-allows-once",onceSheet != nil && once.value == .grant && session.sitePermissions.policy.records.isEmpty,"sheet=\(onceSheet != nil) decision=\(String(describing:once.value)) rules=\(session.sitePermissions.policy.records.count) parentUnchanged=\(runtime.documentID==topDocument) frame=\(String(describing:current.request.url))")
        let detached=request(current)
        await wait{window.attachedSheet != nil || detached.value != nil}
        let detachedSheet=window.attachedSheet
        _=try? await view.evaluateJavaScript("document.querySelector('iframe').remove()")
        if let detachedSheet{window.endSheet(detachedSheet,returnCode:.alertThirdButtonReturn)}
        await wait{detached.value != nil && window.attachedSheet==nil}
        check("removed-frame-denied",detachedSheet != nil && detached.value == .deny && runtime.documentID==topDocument)
        check("removed-frame-grant-not-saved",session.sitePermissions.policy.records.isEmpty)
        let replay=request(initial)
        await wait{replay.value != nil || window.attachedSheet != nil}
        check("detached-frame-cannot-open-new-prompt",replay.value == .deny && window.attachedSheet==nil)
        return results
    }
}
