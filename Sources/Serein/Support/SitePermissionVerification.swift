import AppKit
import WebKit
import SereinCore

/// Exercises the production decision path and real NSAlert sheets. Responses are
/// driven in process, not by AX, and do not assert physical device availability.
@MainActor enum SitePermissionVerification {
    private final class Response { var decision: WKPermissionDecision? }
    private final class ValidationGate {var entered=false;var released=false}

    static func run(session: BrowserSession, root: URL) async -> [RuntimeVerification.Result] {
        guard let runtime=session.current, let window=session.window,
              let url=runtime.webView.url, let origin=SiteOrigin(url:url) else {
            return [.init(name:"permission-delegate-setup",passed:false,detail:"No loaded page")]
        }
        let key=SitePermissionKey(topLevel:origin,requesting:origin,capability:.camera)
        var results:[RuntimeVerification.Result]=[]
        func check(_ name:String,_ passed:Bool) {
            results.append(.init(name:name,passed:passed,detail:"Production permission decision path; in-process NSAlert response, no physical capture assertion"))
        }
        func wait(_ condition:@MainActor ()->Bool) async -> Bool {
            for _ in 0..<100 { if condition(){return true};try? await Task.sleep(for:.milliseconds(50)) }
            return false
        }
        session.sitePermissions.set(.deny,for:[key])
        let denied=Response()
        runtime.decideSitePermission(requesting:origin,capabilities:[.camera]) { denied.decision=$0 }
        check("permission-saved-deny-no-prompt",denied.decision == .deny && window.attachedSheet == nil)
        session.sitePermissions.set(.allow,for:[key])
        let granted=Response()
        runtime.decideSitePermission(requesting:origin,capabilities:[.camera]) { granted.decision=$0 }
        check("permission-saved-allow-no-prompt",granted.decision == .grant && window.attachedSheet == nil)
        let gate=ValidationGate(),revoked=Response()
        runtime.decideSitePermission(requesting:origin,capabilities:[.camera],validation:{
            gate.entered=true
            for _ in 0..<100 {if gate.released{return true};try? await Task.sleep(for:.milliseconds(20))}
            return false
        }) {revoked.decision=$0}
        _=await wait{gate.entered}
        session.sitePermissions.set(.deny,for:[key]);gate.released=true
        _=await wait{revoked.decision != nil}
        check("permission-revoked-during-frame-validation",gate.entered && revoked.decision == .deny && window.attachedSheet==nil)
        session.sitePermissions.reset()
        let once=Response()
        runtime.decideSitePermission(requesting:origin,capabilities:[.camera]) { once.decision=$0 }
        let onceSheet=window.attachedSheet
        check("permission-unknown-shows-sheet",onceSheet != nil && once.decision == nil)
        if onceSheet != nil {
            try? "15-permission-prompt".write(to:root.appendingPathComponent("capture-request"),atomically:true,encoding:.utf8)
            let captured=await wait{FileManager.default.fileExists(atPath:root.appendingPathComponent("15-permission-prompt.capture-finished").path)}
            check("permission-prompt-capture",captured && FileManager.default.fileExists(atPath:root.appendingPathComponent("15-permission-prompt.png").path))
        }
        if let onceSheet { window.endSheet(onceSheet,returnCode:.alertFirstButtonReturn) }
        _=await wait{once.decision != nil}
        check("permission-allow-once-not-persisted",once.decision == .grant && session.sitePermissions.policy.records.isEmpty)
        _=await wait{window.attachedSheet == nil}

        let pending=Response()
        runtime.decideSitePermission(requesting:origin,capabilities:[.camera]) { pending.decision=$0 }
        let staleSheet=window.attachedSheet
        let oldDocument=runtime.documentID
        // Even same-origin navigation must invalidate the original consent request.
        runtime.load(url)
        let navigated=await wait{runtime.documentID != oldDocument}
        if let staleSheet { window.endSheet(staleSheet,returnCode:.alertThirdButtonReturn) }
        _=await wait{pending.decision != nil}
        check("permission-stale-prompt-denied",staleSheet != nil && navigated && pending.decision == .deny)
        check("permission-stale-prompt-not-persisted",session.sitePermissions.policy.records.isEmpty)
        _=await wait{window.attachedSheet == nil && !runtime.isLoading}
        return results
    }
}
