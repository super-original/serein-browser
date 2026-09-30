import XCTest
@testable import SereinCore

final class DownloadRecordTests:XCTestCase {
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
