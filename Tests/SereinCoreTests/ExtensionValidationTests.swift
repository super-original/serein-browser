import XCTest
@testable import SereinCore
final class ExtensionValidationTests: XCTestCase {
    func testUnsupportedManifestsDoNotLoadAsPartialSuccess() {
        for value in ["{\"manifest_version\":4,\"name\":\"A\",\"version\":\"1\"}","{\"manifest_version\":3,\"name\":\"A\",\"version\":\"1\",\"permissions\":[\"nativeMessaging\"]}"] {XCTAssertThrowsError(try ExtensionManifest(data:Data(value.utf8)))}
    }
    func testUnknownRequiredPermissionsAreReportedRatherThanSilentlyDropped() throws {
        let manifest=try ExtensionManifest(data:Data(#"{"manifest_version":2,"name":"Fixture","version":"1","permissions":["storage","webRequestBlocking","https://example.com/*","<all_urls>"]}"#.utf8))
        XCTAssertThrowsError(try manifest.validateRequiredPermissions(recognized:["storage"])) { error in
            XCTAssertTrue(error.localizedDescription.contains("webRequestBlocking"))
            XCTAssertFalse(error.localizedDescription.contains("https://example.com"))
        }
        XCTAssertNoThrow(try manifest.validateRequiredPermissions(recognized:["storage","webRequestBlocking"]))
    }
    func testMalformedPermissionFieldsFailClosed() {
        for field in ["permissions","host_permissions","optional_permissions","optional_host_permissions"] {
            let data=Data("{\"manifest_version\":3,\"name\":\"Fixture\",\"version\":\"1\",\"\(field)\":\"tabs\"}".utf8)
            XCTAssertThrowsError(try ExtensionManifest(data:data))
        }
    }
    func testTraversalAndWindowsPathsAreRejected() {
        for value in ["../escape","/etc/passwd","a/../../outside","C:/file","a\\b","a\0b"] {XCTAssertThrowsError(try ExtensionManifest.validateResourcePath(value))}
        XCTAssertNoThrow(try ExtensionManifest.validateResourcePath("scripts/content.js"))
    }
    func testMalformedArchivesAreRejected() {XCTAssertThrowsError(try ExtensionArchive.validate(Data(repeating:0,count:100)))}
    func testBothManifestGenerationsAreAccepted() throws {
        for version in [2,3] {let manifest=try ExtensionManifest(data:Data("{\"manifest_version\":\(version),\"name\":\"Fixture\",\"version\":\"1.0\"}".utf8));XCTAssertEqual(manifest.manifestVersion,version)}
    }
}
