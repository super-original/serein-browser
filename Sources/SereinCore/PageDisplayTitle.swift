import Foundation

public enum PageDisplayTitle {
    public static func resolve(_ title:String?,url:URL?)->String {
        if let title {
            let value=title.trimmingCharacters(in:.whitespacesAndNewlines)
            if !value.isEmpty {
                return value==url?.absoluteString ? StoredPageURL.removingCredentials(value) ?? "Untitled Page" : value
            }
        }
        guard let url,url.absoluteString != "about:blank" else{return "New Tab"}
        let scheme=url.scheme?.lowercased() ?? ""
        if ["http","https","file","webkit-extension","moz-extension"].contains(scheme) {
            let name=url.lastPathComponent
            if !name.isEmpty,name != "/" {return name}
            if let host=url.host,!host.isEmpty {return host}
        }
        // Never turn a data URL's payload or an opaque resource token into a title.
        return "Untitled Page"
    }
}
