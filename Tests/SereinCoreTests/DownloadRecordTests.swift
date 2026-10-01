import XCTest
@testable import SereinCore

final class DownloadRecordTests:XCTestCase {
    func testResponseMetadataPersistsWithRedactedURL() throws {
        var record=DownloadRecord(source:URL(string:"https://example.com/start"),phase:.complete)
        record.receivedResponse(url:URL(string:"https://user:secret@cdn.example.com/final#private"),mimeType:"text/plain",expectedBytes:42)
        record.receivedBytes=42;record.completed=Date(timeIntervalSince1970:100)
        let data=try DownloadRecord.encodedHistory([record])
        let restored=try XCTUnwrap(DownloadRecord.restoredHistory(data).first)
        XCTAssertEqual(restored.finalURL?.absoluteString,"https://cdn.example.com/final")
        XCTAssertEqual(restored.source?.absoluteString,"https://example.com/start")
        XCTAssertEqual(restored.mimeType,"text/plain")
        XCTAssertEqual(restored.expectedBytes,42);XCTAssertEqual(restored.receivedBytes,42)
        XCTAssertEqual(restored.completed,record.completed)
        XCTAssertFalse(String(decoding:data,as:UTF8.self).contains("secret"))
        record.receivedResponse(url:nil,mimeType:nil,expectedBytes:-1)
        XCTAssertNil(record.expectedBytes);XCTAssertNil(record.finalURL)
    }
    func testLegacyHistoryDoesNotInventResponseMetadata() throws {
        let json="""
        [{"id":"74CAFB75-2C66-4A7C-A159-3CF2B33B3126","name":"Legacy","phase":"complete","detail":"","created":100}]
        """
        let record=try XCTUnwrap(DownloadRecord.restoredHistory(Data(json.utf8)).first)
        XCTAssertEqual(record.name,"Legacy")
        XCTAssertNil(record.finalURL);XCTAssertNil(record.mimeType);XCTAssertNil(record.completed)
        XCTAssertNil(record.expectedBytes);XCTAssertNil(record.receivedBytes)
    }
    func testPrivateHistoryExcludedAndSourceCredentialsRedacted() throws {
        let normal=DownloadRecord(source:URL(string:"https://user:secret@example.com/file#fragment"),phase:.complete)
        let privateRecord=DownloadRecord(name:"Private file",privateWindowID:UUID())
        let data=try DownloadRecord.encodedHistory([normal,privateRecord])
        let restored=try DownloadRecord.restoredHistory(data)
        XCTAssertEqual(restored.count,1)
        XCTAssertEqual(restored[0].source?.absoluteString,"https://example.com/file")
        XCTAssertFalse(String(decoding:data,as:UTF8.self).contains("secret"))
        XCTAssertFalse(String(decoding:data,as:UTF8.self).contains("Private file"))
    }
    func testRestartMarksUnfinishedDownloadsInterrupted() throws {
        let phases:[DownloadPhase]=[.choosing,.downloading,.cancelling,.paused,.complete,.failed,.cancelled]
        let restored=try DownloadRecord.restoredHistory(DownloadRecord.encodedHistory(phases.map{DownloadRecord(phase:$0)}))
        XCTAssertEqual(restored.map(\.phase),[.interrupted,.interrupted,.interrupted,.interrupted,.complete,.failed,.cancelled])
        XCTAssertTrue(restored.allSatisfy{!$0.phase.isActive})
    }
}
