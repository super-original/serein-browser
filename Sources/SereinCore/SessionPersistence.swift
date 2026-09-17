import Foundation

public struct SavedSession: Codable, Sendable {
    public var version: Int = 1
    public var windows: [BrowserWindowState]
    public init(windows: [BrowserWindowState]) {self.windows=windows.filter{!$0.isPrivate}}
    public func encoded() throws -> Data {
        let filtered=SavedSession(windows:windows)
        let encoder=JSONEncoder();encoder.outputFormatting=[.sortedKeys]
        return try encoder.encode(filtered)
    }
    public static func decode(_ data: Data) throws -> SavedSession {
        var session=try JSONDecoder().decode(SavedSession.self,from:data)
        guard session.version==1 else {throw PersistenceError.unsupportedVersion}
        session.windows=session.windows.filter{!$0.isPrivate}.map {var window=$0;window.repair();return window}
        var seen=Set<UUID>();session.windows=session.windows.filter{seen.insert($0.id).inserted}
        return session
    }
}
public enum PersistenceError: Error {case unsupportedVersion}
public enum AddressResolver {
    public static func resolve(_ text: String, searchBase: String = "https://duckduckgo.com/?q=") -> URL? {
        let value=text.trimmingCharacters(in:.whitespacesAndNewlines)
        guard !value.isEmpty else{return nil}
        if value=="about:blank" {return URL(string:value)}
        if let url=URL(string:value),let scheme=url.scheme?.lowercased(),["http","https"].contains(scheme),url.host != nil {return url}
        // Localhost and explicit ports are navigation, not arbitrary executable schemes.
        if !value.contains(where:{$0.isWhitespace}),!value.contains("://"),value.contains(".") || value.hasPrefix("localhost") || value.hasPrefix("[::1]") {
            let prefix=value.hasPrefix("localhost") || value.hasPrefix("127.0.0.1") || value.hasPrefix("[::1]") ? "http://" : "https://"
            if let url=URL(string:prefix+value),url.host != nil {return url}
        }
        var allowed=CharacterSet.urlQueryAllowed;allowed.remove(charactersIn:"&+=?#")
        return URL(string:searchBase+(value.addingPercentEncoding(withAllowedCharacters:allowed) ?? ""))
    }
}
public struct SiteOrigin: Hashable, Codable, Sendable {
    public let scheme: String
    public let host: String
    public let port: Int
    public init?(url: URL) {
        guard let scheme=url.scheme?.lowercased(),["http","https"].contains(scheme),let host=url.host?.lowercased() else{return nil}
        self.scheme=scheme;self.host=host;port=url.port ?? (scheme=="https" ? 443 : 80)
    }
    public var key: String {"\(scheme)://\(host):\(port)"}
}
