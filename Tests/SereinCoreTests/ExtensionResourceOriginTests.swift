import XCTest
@testable import SereinCore

final class ExtensionResourceOriginTests:XCTestCase {
    func testFirefoxPackageOriginDoesNotUseClaimedPublisherIdentity() {
        let id=UUID(uuidString:"12345678-1234-1234-1234-123456789ABC")!
        XCTAssertEqual(ExtensionResourceOrigin.initialURL(sourceExtension:"XPI",id:id)?.absoluteString,"moz-extension://12345678-1234-1234-1234-123456789abc/")
        for suffix in ["zip","crx","appex",""] {XCTAssertNil(ExtensionResourceOrigin.initialURL(sourceExtension:suffix,id:id))}
    }
    func testLegacyAndFirefoxOriginsRemainValid() {
        for value in ["webkit-extension://existing/","moz-extension://generated-id/"] {
            XCTAssertTrue(ExtensionResourceOrigin.isValidBaseURL(URL(string:value)!))
        }
        XCTAssertTrue(ExtensionResourceOrigin.isExtensionScheme("MOZ-EXTENSION"))
        XCTAssertFalse(ExtensionResourceOrigin.isExtensionScheme(nil))
    }
    func testRegistryCannotSelectWebOriginsOrAmbiguousBaseURLs() {
        for value in ["https://example.test/","file:///tmp/","custom://identity/","moz-extension://user:password@identity/","moz-extension://identity:123/","moz-extension://identity/options.html","moz-extension://identity/?query","moz-extension://identity/#fragment"] {
            XCTAssertFalse(ExtensionResourceOrigin.isValidBaseURL(URL(string:value)!),value)
        }
    }
}
