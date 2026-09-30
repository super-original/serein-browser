import XCTest
@testable import SereinCore

final class StoredPageURLTests: XCTestCase {
    func testCredentialsRemovedWithoutChangingDestination() {
        XCTAssertEqual(StoredPageURL.removingCredentials("https://test-user:test-pass@example.test:8443/a%20b?q=one%26two#section"), "https://example.test:8443/a%20b?q=one%26two#section")
        XCTAssertEqual(StoredPageURL.removingCredentials("https://test%40user:p%3Ass@[::1]:8443/path"), "https://[::1]:8443/path")
        XCTAssertEqual(StoredPageURL.removingCredentials("https://test-user@example.test/"), "https://example.test/")
        XCTAssertEqual(StoredPageURL.removingCredentials("about:blank"), "about:blank")
        XCTAssertNil(StoredPageURL.removingCredentials("relative/path"))
        XCTAssertNil(StoredPageURL.webHistoryURL("http-unrelated://example.test/"))
        XCTAssertNil(StoredPageURL.webHistoryURL("file:///tmp/example"))
    }
    func testOpenPinnedClosedAndMutatedSessionsAreSanitized() throws {
        let secret = "https://test-user:test-pass@example.test/page#anchor"
        var window = BrowserWindowState()
        window.tabs[0].url = secret; window.tabs[0].title = secret
        window.setKind(window.tabs[0].id, .pinned)
        window.closedTabs = window.tabs
        var saved = SavedSession(windows: [window])
        // Enforce the boundary even if state is changed after SavedSession initialization.
        saved.windows = [window, BrowserWindowState(isPrivate: true)]
        let data = try saved.encoded(), text = String(decoding: data, as: UTF8.self)
        XCTAssertFalse(text.contains("test-user")); XCTAssertFalse(text.contains("test-pass"))
        let restored = try SavedSession.decode(data)
        XCTAssertEqual(restored.windows.count, 1)
        XCTAssertEqual(restored.windows[0].tabs[0].url, "https://example.test/page#anchor")
        XCTAssertEqual(restored.windows[0].tabs[0].homeURL, "https://example.test/page#anchor")
        XCTAssertEqual(restored.windows[0].closedTabs[0].title, "https://example.test/page#anchor")
        XCTAssertEqual(window.tabs[0].url, secret, "Saving must not mutate a live authentication navigation")
    }
    func testLegacySessionDecodeSanitizesCredentials() throws {
        var saved = SavedSession(windows: [BrowserWindowState()])
        saved.windows[0].tabs[0].url = "https://legacy-user:legacy-pass@example.test/"
        let legacy = try JSONEncoder().encode(saved)
        let restored = try SavedSession.decode(legacy)
        XCTAssertEqual(restored.windows[0].tabs[0].url, "https://example.test/")
    }
}
