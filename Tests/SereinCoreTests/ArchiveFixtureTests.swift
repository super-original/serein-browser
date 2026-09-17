import XCTest
@testable import SereinCore

// ZIP fixtures generated independently using Python standard-library zipfile.
final class ArchiveFixtureTests:XCTestCase {
    func testValidArchive() throws {
        let data=try XCTUnwrap(Data(base64Encoded:"UEsDBBQAAAAIAE6ZMV1Dv6ajBAAAAAIAAAANAAAAbWFuaWZlc3QuanNvbquuBQBQSwMEFAAAAAgATpkxXUO/pqMEAAAAAgAAAAkAAABzY3JpcHQuanOrrgUAUEsBAhQDFAAAAAgATpkxXUO/pqMEAAAAAgAAAA0AAAAAAAAAAAAAAIABAAAAAG1hbmlmZXN0Lmpzb25QSwECFAMUAAAACABOmTFdQ7+mowQAAAACAAAACQAAAAAAAAAAAAAAgAEvAAAAc2NyaXB0LmpzUEsFBgAAAAACAAIAcgAAAFoAAAAAAA=="))
        XCTAssertNoThrow(try ExtensionArchive.validate(data))
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
