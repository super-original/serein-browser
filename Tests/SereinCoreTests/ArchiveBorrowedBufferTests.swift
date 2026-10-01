import XCTest
@testable import SereinCore

final class ArchiveBorrowedBufferTests:XCTestCase {
    func testStoredSliceHasBoundedWritesAndPreservesInput() throws {
        let payload=(0..<(1024*1024+17)).map{UInt8($0%251)}
        let storage:[UInt8]=[255,254,253]+payload+[252,251]
        var received:[UInt8]=[],largest=0
        // Independently calculated with Python zlib.crc32, not the code under test.
        try ArchivePayload.validate(storage[3..<(3+payload.count)],method:0,size:payload.count,checksum:2727182672) {chunk in
            largest=max(largest,chunk.count);received.append(contentsOf:chunk)
        }
        XCTAssertEqual(received,payload)
        XCTAssertLessThanOrEqual(largest,32*1024)
        XCTAssertEqual(Array(storage.prefix(3)),[255,254,253])
        XCTAssertEqual(Array(storage.suffix(2)),[252,251])
        var calls=0
        XCTAssertThrowsError(try ArchivePayload.validate(storage[3..<(3+payload.count)],method:0,size:payload.count,checksum:0){_ in calls+=1})
        XCTAssertEqual(calls,0,"Stored CRC rejection must happen before writing any payload")
    }
    func testDeflatedSliceAndThrowingSinkDoNotMutateInput() throws {
        let compressed=Data(base64Encoded:"7cExAQAAAMKg9U9tDQ+gAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAgFcD")!
        let storage:[UInt8]=[17,19]+Array(compressed)+[23]
        let slice=storage[2..<(2+compressed.count)]
        enum SinkError:Error {case stopped}
        XCTAssertThrowsError(try ArchivePayload.validate(slice,method:8,size:100000,checksum:3557922173){_ in throw SinkError.stopped}) {error in
            XCTAssertTrue(error is SinkError)
        }
        var count=0
        try ArchivePayload.validate(slice,method:8,size:100000,checksum:3557922173) {chunk in
            XCTAssertTrue(chunk.allSatisfy{$0==0});count+=chunk.count
        }
        XCTAssertEqual(count,100000)
        XCTAssertEqual(Array(slice),Array(compressed))
    }
    func testDeflatedExtractionWritesCompleteBoundedChunks() throws {
        // Python zipfile/zlib fixture with a 100,000-byte resource.
        let data=Data(base64Encoded:"UEsDBBQAAAAIAAAAIVx9lRHUcgAAAKCGAQAMAAAAcmVzb3VyY2UuYmlu7cExAQAAAMKg9U9tDQ+gAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAgFcDUEsBAhQDFAAAAAgAAAAhXH2VEdRyAAAAoIYBAAwAAAAAAAAAAAAAAICBAAAAAHJlc291cmNlLmJpblBLBQYAAAAAAQABADoAAACcAAAAAAA=")!
        let parent=FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at:parent,withIntermediateDirectories:false)
        defer{try? FileManager.default.removeItem(at:parent)}
        let destination=parent.appendingPathComponent("unpacked")
        try ExtensionArchive.extract(data,to:destination)
        XCTAssertEqual(try Data(contentsOf:destination.appendingPathComponent("resource.bin")),Data(repeating:0,count:100000))
    }
    func testCorruptLaterPayloadNeverCreatesDestination() throws {
        var data=Data(base64Encoded:"UEsDBBQAAAAIAE6ZMV1Dv6ajBAAAAAIAAAANAAAAbWFuaWZlc3QuanNvbquuBQBQSwMEFAAAAAgATpkxXUO/pqMEAAAAAgAAAAkAAABzY3JpcHQuanOrrgUAUEsBAhQDFAAAAAgATpkxXUO/pqMEAAAAAgAAAA0AAAAAAAAAAAAAAIABAAAAAG1hbmlmZXN0Lmpzb25QSwECFAMUAAAACABOmTFdQ7+mowQAAAACAAAACQAAAAAAAAAAAAAAgAEvAAAAc2NyaXB0LmpzUEsFBgAAAAACAAIAcgAAAFoAAAAAAA==")!
        data[86] ^= 1
        let parent=FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at:parent,withIntermediateDirectories:false)
        defer{try? FileManager.default.removeItem(at:parent)}
        let destination=parent.appendingPathComponent("unpacked")
        XCTAssertThrowsError(try ExtensionArchive.extract(data,to:destination))
        XCTAssertFalse(FileManager.default.fileExists(atPath:destination.path))
    }
}
