import XCTest
@testable import SereinCore

// ZIP fixtures generated independently using Python standard-library zipfile.
final class ArchiveFixtureTests:XCTestCase {
    func testValidArchive() throws {
        let data=try XCTUnwrap(Data(base64Encoded:"UEsDBBQAAAAIAE6ZMV1Dv6ajBAAAAAIAAAANAAAAbWFuaWZlc3QuanNvbquuBQBQSwMEFAAAAAgATpkxXUO/pqMEAAAAAgAAAAkAAABzY3JpcHQuanOrrgUAUEsBAhQDFAAAAAgATpkxXUO/pqMEAAAAAgAAAA0AAAAAAAAAAAAAAIABAAAAAG1hbmlmZXN0Lmpzb25QSwECFAMUAAAACABOmTFdQ7+mowQAAAACAAAACQAAAAAAAAAAAAAAgAEvAAAAc2NyaXB0LmpzUEsFBgAAAAACAAIAcgAAAFoAAAAAAA=="))
        XCTAssertNoThrow(try ExtensionArchive.validate(data))
    }
    func testPayloadValidationRejectsLyingSizesAndChecksums() throws {
        // Raw deflate of 100,000 zero bytes, produced independently by Python zlib.
        let compressed = Data(base64Encoded: "7cExAQAAAMKg9U9tDQ+gAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAgFcD")!
        let checksum: UInt32 = 3557922173
        XCTAssertNoThrow(try ArchivePayload.validate(Array(compressed)[...], method: 8, size: 100000, checksum: checksum))
        XCTAssertThrowsError(try ArchivePayload.validate(Array(compressed)[...], method: 8, size: 10, checksum: checksum))
        XCTAssertThrowsError(try ArchivePayload.validate(Array(compressed)[...], method: 8, size: 100000, checksum: checksum ^ 1))
        XCTAssertThrowsError(try ArchivePayload.validate(Array(compressed.dropLast())[...], method: 8, size: 100000, checksum: checksum))
        XCTAssertThrowsError(try ArchivePayload.validate(Array(compressed + Data([0]))[...], method: 8, size: 100000, checksum: checksum))
        XCTAssertThrowsError(try ArchivePayload.validate([1,2,3][...], method: 0, size: 2, checksum: 0))
    }
    func testTraversalArchive() throws {
        let data=try XCTUnwrap(Data(base64Encoded:"UEsDBBQAAAAIAE6ZMV1Dv6ajBAAAAAIAAAAMAAAALi4vZXNjYXBlLmpzq64FAFBLAQIUAxQAAAAIAE6ZMV1Dv6ajBAAAAAIAAAAMAAAAAAAAAAAAAACAAQAAAAAuLi9lc2NhcGUuanNQSwUGAAAAAAEAAQA6AAAALgAAAAAA"))
        XCTAssertThrowsError(try ExtensionArchive.validate(data))
    }
    func testAbsoluteArchive() throws {
        let data=try XCTUnwrap(Data(base64Encoded:"UEsDBBQAAAAIAE6ZMV1Dv6ajBAAAAAIAAAAOAAAAL3RtcC9lc2NhcGUuanOrrgUAUEsBAhQDFAAAAAgATpkxXUO/pqMEAAAAAgAAAA4AAAAAAAAAAAAAAIABAAAAAC90bXAvZXNjYXBlLmpzUEsFBgAAAAABAAEAPAAAADAAAAAAAA=="))
        XCTAssertThrowsError(try ExtensionArchive.validate(data))
    }
    func testDuplicateArchive() throws {
        let data=try XCTUnwrap(Data(base64Encoded:"UEsDBBQAAAAIAE6ZMV1Dv6ajBAAAAAIAAAAJAAAAU2NyaXB0Lmpzq64FAFBLAwQUAAAACABOmTFdQ7+mowQAAAACAAAACQAAAHNjcmlwdC5qc6uuBQBQSwECFAMUAAAACABOmTFdQ7+mowQAAAACAAAACQAAAAAAAAAAAAAAgAEAAAAAU2NyaXB0LmpzUEsBAhQDFAAAAAgATpkxXUO/pqMEAAAAAgAAAAkAAAAAAAAAAAAAAIABKwAAAHNjcmlwdC5qc1BLBQYAAAAAAgACAG4AAABWAAAAAAA="))
        XCTAssertThrowsError(try ExtensionArchive.validate(data))
    }
}
