import AppKit
import WebKit
import SereinCore

/// A separate diagnostic controller, never the production extension host.
/// It can only return a constant protocol reply; it cannot execute programs,
/// read browser data, access files, or route to any other application.
@MainActor private final class NativeBridgeProbeDelegate:NSObject,WKWebExtensionControllerDelegate {
    var expectedContext=""
    var allowed=0
    var rejected=0
    func webExtensionController(_ controller:WKWebExtensionController,sendMessage message:Any,toApplicationWithIdentifier applicationIdentifier:String?,for context:WKWebExtensionContext,replyHandler:@escaping (Any?,(any Error)?)->Void) {
        guard applicationIdentifier=="dev.serein.compat.probe",context.uniqueIdentifier==expectedContext,
              context.hasPermission(WKWebExtension.Permission(rawValue:"nativeMessaging")),
              let request=message as? [String:Any],request.count==1,request["operation"] as? String=="probe" else {
            rejected += 1;replyHandler(nil,ExtensionValidationError.invalid("Unregistered application or operation."));return
        }
        allowed += 1
        replyHandler(["protocol":"serein-probe-1","context":expectedContext],nil)
    }
}
@MainActor enum NativeBridgeVerification {
    static func run(root:URL) async -> [RuntimeVerification.Result] {
        var results:[RuntimeVerification.Result]=[]
        func check(_ name:String,_ passed:Bool,_ detail:String="") {results.append(.init(name:name,passed:passed,detail:detail))}
        for version in [2,3] {
            let prefix="mv\(version)-native-bridge"
            do {
                let controller=WKWebExtensionController(),delegate=NativeBridgeProbeDelegate()
                controller.delegate=delegate
                let source=Bundle.main.resourceURL!.appendingPathComponent("Fixtures/NativeBridge/mv\(version)")
                let ext=try await WKWebExtension(resourceBaseURL:source)
                guard ext.errors.isEmpty else{throw ExtensionValidationError.invalid(ext.errors.map(\.localizedDescription).joined(separator:"; "))}
                check(prefix+"-permission-recognized",ext.requestedPermissions.contains{ $0.rawValue=="nativeMessaging" })
                let context=WKWebExtensionContext(for:ext);context.uniqueIdentifier=UUID().uuidString
                delegate.expectedContext=context.uniqueIdentifier
                for pattern in ext.requestedPermissionMatchPatterns {context.setPermissionStatus(.grantedExplicitly,for:pattern)}
                try controller.load(context)
                defer {try? controller.unload(context)}
                let config=WKWebViewConfiguration();config.webExtensionController=controller
                let view=WKWebView(frame:NSRect(x:0,y:0,width:640,height:480),configuration:config)
                defer {view.stopLoading()}
                func probe(_ stage:String) async -> [String:Any]? {
                    view.load(URLRequest(url:URL(string:"http://127.0.0.1:8765/index.html?native=\(version)-\(stage)")!))
                    for _ in 0..<100 {
                        try? await Task.sleep(for:.milliseconds(100))
                        if let value=try? await view.evaluateJavaScript("location.search === '?native=\(version)-\(stage)' ? (document.documentElement.dataset.sereinNativeProbe || null) : null"),let string=value as? String,let data=string.data(using:.utf8),let response=(try? JSONSerialization.jsonObject(with:data)) as? [String:Any] {return response}
                    }
                    return nil
                }
                let denied=await probe("denied")
                check(prefix+"-denied-before-host",denied?["allowed"] as? Bool==false && delegate.allowed==0 && delegate.rejected==0,String(describing:denied))
                context.setPermissionStatus(.grantedExplicitly,for:WKWebExtension.Permission(rawValue:"nativeMessaging"))
                let granted=await probe("granted")
                let response=granted?["response"] as? [String:String]
                check(prefix+"-scoped-reply",granted?["allowed"] as? Bool==true && response?["protocol"]=="serein-probe-1" && response?["context"]==delegate.expectedContext && delegate.allowed==1,String(describing:granted))
                check(prefix+"-unknown-application-denied",granted?["unknownRejected"] as? Bool==true && delegate.rejected==1)
            } catch {check(prefix+"-setup",false,error.localizedDescription)}
        }
        try? JSONEncoder().encode(results).write(to:root.appendingPathComponent("native-bridge-probe.json"),options:.atomic)
        return results
    }
}
