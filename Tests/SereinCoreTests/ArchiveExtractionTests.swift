import XCTest
@testable import SereinCore

final class ArchiveExtractionTests: XCTestCase {
    func testExtractionCannotReinterpretAlternatePathMetadata() throws {
        // Independent ZIP contains a Unicode Path extra naming ../outside.json.
        // Serein intentionally uses only its validated UTF-8 central/local names.
        let data = Data(base64Encoded: "UEsDBBQAAAAIAAAAIQBDv6ajBAAAAAIAAAANABgAbWFuaWZlc3QuanNvbnVwFAAB7fb/FC4uL291dHNpZGUuanNvbquuBQBQSwECFAMUAAAACAAAACEAQ7+mowQAAAACAAAADQAYAAAAAAAAAAAAgAEAAAAAbWFuaWZlc3QuanNvbnVwFAAB7fb/FC4uL291dHNpZGUuanNvblBLBQYAAAAAAQABAFMAAABHAAAAAAA=")!
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: false)
        defer { try? FileManager.default.removeItem(at: root) }
        let destination = root.appendingPathComponent("unpacked")
        try ExtensionArchive.extract(data, to: destination)
        XCTAssertEqual(try String(contentsOf: destination.appendingPathComponent("manifest.json"), encoding: .utf8), "{}")
        XCTAssertFalse(FileManager.default.fileExists(atPath: root.appendingPathComponent("outside.json").path))
        XCTAssertThrowsError(try ExtensionArchive.extract(data, to: destination), "Existing destinations must never be overwritten")
        XCTAssertEqual(try String(contentsOf: destination.appendingPathComponent("manifest.json"), encoding: .utf8), "{}")
    }
}
