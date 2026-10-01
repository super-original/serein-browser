import Foundation

/// URL userinfo belongs to a navigation/authentication flow, never saved browsing records.
/// Query parameters and fragments are deliberately preserved; this is not a general secret detector.
public enum StoredPageURL {
    public static func removingCredentials(_ value: String) -> String? {
        guard var components = URLComponents(string: value), components.scheme != nil,
              components.url != nil else { return nil }
        guard components.user != nil || components.password != nil else { return value }
        components.user = nil; components.password = nil
        return components.string
    }
    public static func webHistoryURL(_ value: String) -> String? {
        guard let sanitized = removingCredentials(value), let url = URL(string: sanitized),
              ["http", "https"].contains(url.scheme?.lowercased() ?? ""),
              let host = url.host, !host.isEmpty else { return nil }
        return sanitized
    }
    static func sanitize(_ tab: BrowserTab) -> BrowserTab {
        var result = tab
        result.url = removingCredentials(tab.url) ?? "about:blank"
        if tab.title == tab.url { result.title = result.url }
        result.homeURL = tab.homeURL.map { removingCredentials($0) ?? "about:blank" }
        return result
    }
    static func sanitize(_ window: BrowserWindowState) -> BrowserWindowState {
        var result = window
        result.tabs = window.tabs.map(sanitize)
        result.closedTabs = window.closedTabs.map(sanitize)
        return result
    }
}
