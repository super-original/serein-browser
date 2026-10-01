import Foundation

public struct SavedSession: Codable, Sendable {
    public var version: Int = 1
    public var windows: [BrowserWindowState]
    public var navigationHistory:[SavedNavigationHistory]?
    public init(windows: [BrowserWindowState],navigationHistory:[SavedNavigationHistory]=[]) {
        self.windows=windows.filter{!$0.isPrivate}.map(StoredPageURL.sanitize)
        self.navigationHistory=SavedNavigationHistory.validated(navigationHistory,windows:self.windows)
    }
    private enum CodingKeys:String,CodingKey {case version,windows,navigationHistory}
    public init(from decoder:Decoder) throws {
        let values=try decoder.container(keyedBy:CodingKeys.self)
        version=try values.decode(Int.self,forKey:.version)
        windows=try values.decode([BrowserWindowState].self,forKey:.windows)
        // Optional engine state must never make ordinary tab restoration fail.
        navigationHistory=try? values.decode([SavedNavigationHistory].self,forKey:.navigationHistory)
    }
    public func encoded() throws -> Data {
        let filtered=SavedSession(windows:windows,navigationHistory:navigationHistory ?? [])
        let encoder=JSONEncoder();encoder.outputFormatting=[.sortedKeys]
        return try encoder.encode(filtered)
    }
    public static func decode(_ data: Data) throws -> SavedSession {
        guard data.count<=32*1024*1024 else {throw PersistenceError.oversizedSession}
        var session=try JSONDecoder().decode(SavedSession.self,from:data)
        guard session.version==1 else {throw PersistenceError.unsupportedVersion}
        session.windows=session.windows.filter{!$0.isPrivate}.map {var window=StoredPageURL.sanitize($0);window.repair();return window}
        var seen=Set<UUID>();session.windows=session.windows.filter{seen.insert($0.id).inserted}
        session.navigationHistory=SavedNavigationHistory.validated(session.navigationHistory ?? [],windows:session.windows)
        return session
    }
}
public enum PersistenceError: Error {case unsupportedVersion, oversizedSession}
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
