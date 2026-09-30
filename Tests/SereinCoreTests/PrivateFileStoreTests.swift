import XCTest
@testable import SereinCore

final class PrivateFileStoreTests:XCTestCase {
    func testMigrationAndAtomicReplacementRemainOwnerOnly() throws {
        let parent=FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer {try? FileManager.default.removeItem(at:parent)}
        let root=parent.appendingPathComponent("Serein"),unrelated=parent.appendingPathComponent("Unrelated")
        try FileManager.default.createDirectory(at:root,withIntermediateDirectories:true)
        try FileManager.default.createDirectory(at:unrelated,withIntermediateDirectories:true)
        try FileManager.default.setAttributes([.posixPermissions:0o755],ofItemAtPath:root.path)
        try FileManager.default.setAttributes([.posixPermissions:0o755],ofItemAtPath:unrelated.path)
        let file=root.appendingPathComponent("session.json")
        try Data("old".utf8).write(to:file)
        try FileManager.default.setAttributes([.posixPermissions:0o644],ofItemAtPath:file.path)
        for content in ["first replacement","second replacement"] {
            try PrivateFileStore.write(Data(content.utf8),to:file)
            XCTAssertEqual(try Data(contentsOf:file),Data(content.utf8))
            XCTAssertEqual(try permissions(root),0o700)
            XCTAssertEqual(try permissions(file),0o600)
            XCTAssertEqual(try permissions(unrelated),0o755)
        }
    }
    func testInvalidParentPreservesExistingData() throws {
        let root=FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer {try? FileManager.default.removeItem(at:root)}
        try PrivateFileStore.prepareDirectory(root)
        let parentFile=root.appendingPathComponent("existing-file")
        let original=Data("keep this file".utf8);try original.write(to:parentFile)
        XCTAssertThrowsError(try PrivateFileStore.write(Data("new".utf8),to:parentFile.appendingPathComponent("record.json")))
        XCTAssertEqual(try Data(contentsOf:parentFile),original)
    }
    private func permissions(_ url:URL) throws -> Int {
        try XCTUnwrap(FileManager.default.attributesOfItem(atPath:url.path)[.posixPermissions] as? NSNumber).intValue
    }
}
