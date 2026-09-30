import XCTest
@testable import SereinCore

final class ExtensionPackageLayoutTests:XCTestCase {
    func fixture(_ point:String="com.apple.Safari.web-extension") throws -> URL {
        let root=FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString+".appex")
        try FileManager.default.createDirectory(at:root.appendingPathComponent("Contents/Resources"),withIntermediateDirectories:true)
        let plist:[String:Any]=["CFBundleIdentifier":"org.serein.test","CFBundlePackageType":"XPC!","NSExtension":["NSExtensionPointIdentifier":point]]
        try PropertyListSerialization.data(fromPropertyList:plist,format:.xml,options:0).write(to:root.appendingPathComponent("Contents/Info.plist"))
        try Data("{}".utf8).write(to:root.appendingPathComponent("Contents/Resources/manifest.json"))
        return root
    }
    func testSafariWebBundleUsesItsResourcesWithoutChangingBytes() throws {
        let root=try fixture();defer{try? FileManager.default.removeItem(at:root)}
        let before=try Data(contentsOf:root.appendingPathComponent("Contents/Info.plist"))
        let layout=try ExtensionPackageLayout.inspect(root)
        XCTAssertTrue(layout.isSafariBundle);XCTAssertEqual(layout.resources,root.appendingPathComponent("Contents/Resources"))
        XCTAssertEqual(try Data(contentsOf:root.appendingPathComponent("Contents/Info.plist")),before)
    }
    func testNativeSafariBundleIsExplicitlyRejected() throws {
        let root=try fixture("com.apple.Safari.extension");defer{try? FileManager.default.removeItem(at:root)}
        XCTAssertThrowsError(try ExtensionPackageLayout.inspect(root)) {XCTAssertTrue($0.localizedDescription.contains("Native Safari App Extensions"))}
    }
    func testMissingManifestAndMalformedMetadataFail() throws {
        let root=try fixture();defer{try? FileManager.default.removeItem(at:root)}
        try FileManager.default.removeItem(at:root.appendingPathComponent("Contents/Resources/manifest.json"))
        XCTAssertThrowsError(try ExtensionPackageLayout.inspect(root))
        try Data("invalid plist".utf8).write(to:root.appendingPathComponent("Contents/Info.plist"))
        XCTAssertThrowsError(try ExtensionPackageLayout.inspect(root))
    }
    func testPlainManifestFolderKeepsLegacyLayout() throws {
        let root=FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let layout=try ExtensionPackageLayout.inspect(root)
        XCTAssertFalse(layout.isSafariBundle);XCTAssertEqual(layout.resources,root)
    }
}
