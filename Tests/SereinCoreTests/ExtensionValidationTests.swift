import XCTest
@testable import SereinCore
final class ExtensionValidationTests: XCTestCase {
    func testOriginalAPIDeclarationsIncludeOptionalButNeverHostPatterns() throws {
        let data=Data(#"{"name":"Boundary","version":"1","manifest_version":3,"permissions":["storage","http://example.com/*"],"optional_permissions":["nativeMessaging","<all_urls>"],"host_permissions":["https://example.com/*"]}"#.utf8)
        let manifest=try ExtensionManifest(data:data)
        XCTAssertEqual(manifest.declaredAPIPermissions,["storage","nativeMessaging"])
        XCTAssertFalse(manifest.permissions.contains("nativeMessaging"))
        let plain=try ExtensionManifest(data:Data(#"{"name":"Plain","version":"1","manifest_version":3}"#.utf8))
        XCTAssertTrue(plain.declaredAPIPermissions.isEmpty)
    }
    func testNativeMessagingRequiresVerifiedPackageIdentity() throws {
        let manifest=try ExtensionManifest(data:Data("{\"manifest_version\":3,\"name\":\"A\",\"version\":\"1\",\"permissions\":[\"nativeMessaging\"]}".utf8))
        XCTAssertThrowsError(try manifest.validateNativeMessagingIdentity(nil))
        let chrome=SignedExtensionIdentity(format:"CRX3",extensionID:String(repeating:"a",count:32),publicKeySHA256:"fixture",packageSHA256:"fixture")
        XCTAssertNoThrow(try manifest.validateNativeMessagingIdentity(chrome))
        let firefox=SignedExtensionIdentity(format:"XPI",extensionID:"example@fixture",publicKeySHA256:"fixture",packageSHA256:"fixture")
        XCTAssertThrowsError(try manifest.validateNativeMessagingIdentity(firefox))
    }

    func testActionCommandNormalizationPreservesCapabilities() throws {
        for (version,action) in [(2,"_execute_browser_action"),(3,"_execute_action")] {
            let original=Data("{\"manifest_version\":\(version),\"permissions\":[\"webRequestBlocking\"],\"commands\":{\"\(action)\":{},\"ordinary\":{}}}".utf8)
            let normalized=try ExtensionCommandNormalization.normalize(original)
            let json=try XCTUnwrap(JSONSerialization.jsonObject(with:normalized) as? [String:Any])
            let commands=try XCTUnwrap(json["commands"] as? [String:[String:Any]])
            XCTAssertEqual(commands[action]?["description"] as? String,"Activate extension")
            XCTAssertEqual(commands["ordinary"]?.count,0)
            XCTAssertEqual(json["permissions"] as? [String],["webRequestBlocking"])
            XCTAssertEqual(try ExtensionCommandNormalization.normalize(normalized),normalized)
        }
    }
    func testNonemptyActionAndOrdinaryCommandsAreUntouched() throws {
        let original=Data(#"{"manifest_version":3,"commands":{"_execute_action":{"suggested_key":{"default":"Ctrl+Shift+Y"}},"ordinary":{}}}"#.utf8)
        XCTAssertEqual(try ExtensionCommandNormalization.normalize(original),original)
    }
    func testUnsupportedManifestsDoNotLoadAsPartialSuccess() {
        for value in ["{\"manifest_version\":4,\"name\":\"A\",\"version\":\"1\"}"] {XCTAssertThrowsError(try ExtensionManifest(data:Data(value.utf8)))}
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
