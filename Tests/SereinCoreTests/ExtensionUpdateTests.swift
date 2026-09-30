import XCTest
@testable import SereinCore

final class ExtensionUpdateTests: XCTestCase {
    func testNumericVersionOrderingAndValidation() throws {
        XCTAssertEqual(try ExtensionVersion("1"), try ExtensionVersion("1.0.0.0"))
        XCTAssertLessThan(try ExtensionVersion("1.9.65535"), try ExtensionVersion("1.10"))
        XCTAssertLessThan(try ExtensionVersion("1.1.9.9999"), try ExtensionVersion("1.2"))
        for invalid in ["", "0", "0.0.0.0", "01", "1..2", "1.65536", "1.2.3.4.5", "1-beta", "١.٢", "-1", "1. 2"] {
            XCTAssertThrowsError(try ExtensionVersion(invalid), invalid)
        }
    }
    func testDeveloperBindingAndDowngradeRejection() throws {
        let original = SignedExtensionIdentity(format: "CRX3", extensionID: "test-id", publicKeySHA256: "first-key", packageSHA256: "old-package")
        let candidate = SignedExtensionIdentity(format: "CRX3", extensionID: "test-id", publicKeySHA256: "first-key", packageSHA256: "new-package")
        XCTAssertNoThrow(try SignedExtensionUpdate.validate(previous: original, version: "1", candidate: candidate, candidateVersion: "1.1"))
        for version in ["0.9", "1.0.0"] {
            XCTAssertThrowsError(try SignedExtensionUpdate.validate(previous: original, version: "1", candidate: candidate, candidateVersion: version))
        }
        let wrongKey = SignedExtensionIdentity(format: "CRX3", extensionID: "test-id", publicKeySHA256: "different-key", packageSHA256: "new-package")
        XCTAssertThrowsError(try SignedExtensionUpdate.validate(previous: original, version: "1", candidate: wrongKey, candidateVersion: "2"))
    }
    func testAtomicRegistryCommitKeepsPreviousPackage() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: false)
        defer { try? FileManager.default.removeItem(at: root) }
        let recordID = UUID(), versionID = UUID()
        let previous = ExtensionPackageStorage.directory(root: root, recordID: recordID, versionID: nil)
        let candidate = root.appendingPathComponent("candidate")
        for directory in [previous, candidate] { try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: false) }
        try Data("old".utf8).write(to: previous.appendingPathComponent("manifest.json"))
        try Data("new".utf8).write(to: candidate.appendingPathComponent("manifest.json"))
        let registry = root.appendingPathComponent("extensions.json")
        try Data("old-registry".utf8).write(to: registry)
        // A prepared but uncommitted candidate leaves the durable old pointer intact.
        XCTAssertEqual(try Data(contentsOf: registry), Data("old-registry".utf8))
        try ExtensionPackageStorage.commitPrepared(candidate, root: root, versionID: versionID, registry: Data("new-registry".utf8))
        XCTAssertEqual(try Data(contentsOf: registry), Data("new-registry".utf8))
        XCTAssertEqual(try Data(contentsOf: previous.appendingPathComponent("manifest.json")), Data("old".utf8))
        let current = ExtensionPackageStorage.directory(root: root, recordID: recordID, versionID: versionID)
        XCTAssertEqual(try Data(contentsOf: current.appendingPathComponent("manifest.json")), Data("new".utf8))
        XCTAssertThrowsError(try ExtensionPackageStorage.commitPrepared(previous, root: root, versionID: versionID, registry: Data("unexpected".utf8)))
        XCTAssertEqual(try Data(contentsOf: registry), Data("new-registry".utf8))
        XCTAssertTrue(FileManager.default.fileExists(atPath: previous.path))
    }
    func testFailedRegistryWriteRemovesOnlyNewVersion() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: false)
        defer { try? FileManager.default.removeItem(at: root) }
        let candidate = root.appendingPathComponent("candidate"), version = UUID()
        try FileManager.default.createDirectory(at: candidate, withIntermediateDirectories: false)
        try FileManager.default.createDirectory(at: root.appendingPathComponent("extensions.json"), withIntermediateDirectories: false)
        XCTAssertThrowsError(try ExtensionPackageStorage.commitPrepared(candidate, root: root, versionID: version, registry: Data("record".utf8)))
        XCTAssertFalse(FileManager.default.fileExists(atPath: root.appendingPathComponent("Versions").appendingPathComponent(version.uuidString).path))
        var directory: ObjCBool = false
        XCTAssertTrue(FileManager.default.fileExists(atPath: root.appendingPathComponent("extensions.json").path, isDirectory: &directory))
        XCTAssertTrue(directory.boolValue)
    }
}
