import WebKit

/// Controlled engine diagnostic, using a distinct controller and storage identity.
/// This does not alter production permission admission or claim compatibility.
@MainActor enum ExtensionReloadProbe {
    static func inspectHost(context:WKWebExtensionContext, dataStore:WKWebsiteDataStore, version:String, history:Any?) async -> [RuntimeVerification.Result] {
        var results:[RuntimeVerification.Result]=[]
        for (customize,restoreHistory) in [(false,false),(true,false),(false,true),(true,true)] {
            if restoreHistory,history==nil {
                results.append(.init(name:"host-extension-history-setup",passed:false,detail:"No opaque history was supplied"));continue
            }
            guard let configuration=context.webViewConfiguration,let url=context.optionsPageURL else{return results}
            if customize {
                configuration.websiteDataStore=dataStore
                let content=WKUserContentController()
                for script in configuration.userContentController.userScripts {content.addUserScript(script)}
                configuration.userContentController=content
                configuration.preferences.isElementFullscreenEnabled=true
                configuration.preferences.javaScriptCanOpenWindowsAutomatically=false
            }
            let view=WKWebView(frame:.zero,configuration:configuration)
            if restoreHistory,let history {view.interactionState=history} else {view.load(url)}
            var body=""
            for _ in 0..<50 {
                body=(try? await view.evaluateJavaScript("document.body?.innerText ?? ''") as? String) ?? ""
                if body=="Version "+version {break}
                try? await Task.sleep(for:.milliseconds(100))
            }
            results.append(.init(name:"host-extension-"+(customize ? "customized" : "raw")+(restoreHistory ? "-history" : "")+"-options",passed:body=="Version "+version,detail:"url=\(String(describing:view.url)) body=\(body) ownOriginPermission=\(context.permissionStatus(for:url).rawValue)"))
            view.stopLoading()
        }
        return results
    }
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
                    if let text,text=="Version "+version,!view.isLoading {return (true,text)}
                    detail=text ?? "non-string document"
                } catch{detail=error.localizedDescription}
                try? await Task.sleep(for:.milliseconds(100))
            }
            return (false,"url=\(String(describing:view.url)) title=\(view.title ?? "nil") \(detail)")
        }
        do {
            var base:URL?
            var history:Any?
            for phase in ["fresh", "reload", "history-reload", "warm-history-reload", "restricted-reload"] {
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
                if phase=="history-reload",let history {
                    view!.interactionState=history
                } else {
                    view!.load(url)
                    if phase=="warm-history-reload",let history {
                        let preload=await document(view!)
                        results.append(.init(name:"isolated-extension-history-preload",passed:preload.0,detail:preload.1))
                        view!.interactionState=history
                    }
                }
                try? await Task.sleep(for:.milliseconds(200))
                let result=await document(view!)
                if phase=="fresh",result.0 {history=view!.interactionState}
                results.append(.init(name:"isolated-extension-"+phase+"-options",passed:result.0,detail:result.1+" ownOriginPermission=\(context.permissionStatus(for:url).rawValue) errors="+context.errors.map(\.localizedDescription).joined(separator:"; ")))
                view?.stopLoading();view=nil
                try controller.unload(context);loaded=nil
                if phase=="fresh",!result.0 {return results}
            }
        } catch{results.append(.init(name:"isolated-extension-reload-setup",passed:false,detail:error.localizedDescription))}
        return results
    }
}
