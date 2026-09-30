import XCTest
@testable import SereinCore

final class SitePermissionTests: XCTestCase {
    private func key(_ top: String = "https://example.com", _ requester: String = "https://example.com", _ capability: SiteCapability = .camera) -> SitePermissionKey {
        SitePermissionKey(topLevel: SiteOrigin(url: URL(string: top)!)!, requesting: SiteOrigin(url: URL(string: requester)!)!, capability: capability)
    }

    func testGrantsDoNotCrossOriginsOrCapabilities() {
        var policy = SitePermissionPolicy()
        policy.set(.allow, for: key())
        XCTAssertEqual(policy.decision(for: [key("https://example.com/path", "https://example.com:443/other")]), .allow)
        for other in [key("http://example.com"), key("https://example.com:8443"), key("https://other.com"), key("https://example.com", "https://embed.example.com"), key("https://example.com", "https://example.com", .microphone)] {
            XCTAssertEqual(policy.decision(for: [other]), .ask)
        }
    }

    func testCombinedCaptureRequiresEveryGrantAndDenyWins() {
        var policy = SitePermissionPolicy()
        let camera = key(), microphone = key("https://example.com", "https://example.com", .microphone)
        policy.set(.allow, for: camera)
        XCTAssertEqual(policy.decision(for: [camera, microphone]), .ask)
        policy.set(.allow, for: microphone)
        XCTAssertEqual(policy.decision(for: [camera, microphone]), .allow)
        policy.set(.deny, for: camera)
        XCTAssertEqual(policy.decision(for: [camera, microphone]), .deny)
        XCTAssertEqual(policy.decision(for: []), .deny)
    }

    func testRoundTripRevocationAndReset() throws {
        var policy = SitePermissionPolicy()
        policy.set(.allow, for: key())
        policy.set(.deny, for: key("https://other.com"))
        var restored = try JSONDecoder().decode(SitePermissionPolicy.self, from: JSONEncoder().encode(policy))
        XCTAssertEqual(restored.decision(for: [key()]), .allow)
        XCTAssertEqual(restored.decision(for: [key("https://other.com")]), .deny)
        restored.set(.ask, for: key())
        XCTAssertEqual(restored.decision(for: [key()]), .ask)
        XCTAssertEqual(restored.records.count, 1)
        restored.reset()
        XCTAssertEqual(restored.decision(for: [key("https://other.com")]), .ask)
    }
}
