import WebKit

/// Controlled engine diagnostic, using a distinct controller and storage identity.
/// This does not alter production permission admission or claim compatibility.
@MainActor enum ExtensionReloadProbe {
    static func run(directory:URL,version:String) async -> [RuntimeVerification.Result] {
        var results:[RuntimeVerification.Result]=[]
        let controller=WKWebExtensionController(configuration:.init(identifier:UUID()))
        var loaded:WKWebExtensionContext?
        defer{if let loaded{try? controller.unload(loaded)}}
        let identifier=UUID().uuidString
        func document(_ view:WKWebView) async -> (Bool,String) {
            var detail=""
            for _ in 0..<50 {
                do {
                    let text=try await view.evaluateJavaScript("document.body?.innerText ?? ''") as? String
                    if let text,text=="Version "+version {return (true,text)}
                    detail=text ?? "non-string document"
                } catch{detail=error.localizedDescription}
                try? await Task.sleep(for:.milliseconds(100))
            }
            return (false,"url=\(String(describing:view.url)) title=\(view.title ?? "nil") \(detail)")
        }
        do {
            var base:URL?
            for phase in ["fresh", "reload", "restricted-reload"] {
                let ext=try await WKWebExtension(resourceBaseURL:directory)
                let context=WKWebExtensionContext(for:ext);context.uniqueIdentifier=identifier
                if let base {context.baseURL=base}
                for permission in ext.requestedPermissions where phase != "restricted-reload" || permission.rawValue != "tabs" {
                    context.setPermissionStatus(.grantedExplicitly,for:permission)
                }
                if phase=="restricted-reload" {context.setPermissionStatus(.deniedExplicitly,for:URL(string:"http://127.0.0.1:8765/index.html")!)}
                try controller.load(context);loaded=context;base=context.baseURL
                guard let configuration=context.webViewConfiguration,let url=context.optionsPageURL else{throw NSError(domain:"ExtensionReloadProbe",code:1)}
                var view:WKWebView?=WKWebView(frame:.zero,configuration:configuration)
                view!.load(url)
                let result=await document(view!)
                results.append(.init(name:"isolated-extension-"+phase+"-options",passed:result.0,detail:result.1+" ownOriginPermission=\(context.permissionStatus(for:url).rawValue) errors="+context.errors.map(\.localizedDescription).joined(separator:"; ")))
                view?.stopLoading();view=nil
                try controller.unload(context);loaded=nil
                if phase=="fresh",!result.0 {return results}
            }
        } catch{results.append(.init(name:"isolated-extension-reload-setup",passed:false,detail:error.localizedDescription))}
        return results
    }
}
