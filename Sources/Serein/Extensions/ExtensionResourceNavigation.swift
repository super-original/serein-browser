import WebKit
import SereinCore

extension ExtensionHost {
    func allowsPageNavigation(to url:URL,context:WKWebExtensionContext,from origin:WKSecurityOrigin) -> Bool {
        var components=URLComponents()
        components.scheme=origin.protocol;components.host=origin.host
        if origin.port>0 {components.port=origin.port}
        guard let source=components.url else{return false}
        let sourceContext=controller.extensionContext(for:source)
        if sourceContext === context {return true}
        return ExtensionResourceAccess.allows(path:url.path,manifest:context.webExtension.manifest,sourceExtensionID:sourceContext?.uniqueIdentifier) { pattern in
            guard ["http","https","file"].contains(source.scheme?.lowercased() ?? ""),let match=try? WKWebExtension.MatchPattern(string:pattern) else{return false}
            return match.matches(source,options:.ignorePaths)
        }
    }
}
