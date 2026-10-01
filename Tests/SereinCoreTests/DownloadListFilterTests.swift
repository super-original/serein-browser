import XCTest
@testable import SereinCore

final class DownloadListFilterTests:XCTestCase {
    func testEveryPhaseHasExactlyOneNonAllCategory() {
        let phases:[DownloadPhase]=[.choosing,.downloading,.cancelling,.paused,.complete,.failed,.cancelled,.interrupted]
        for phase in phases {
            let record=DownloadRecord(phase:phase)
            XCTAssertTrue(DownloadListFilter.all.includes(record))
            XCTAssertEqual(DownloadListFilter.allCases.filter{$0 != .all && $0.includes(record)}.count,1)
        }
    }
    func testSearchIncludesRedirectAndFilenameButNotCredentialsOrParentPath() {
        var record=DownloadRecord(name:"Report",source:URL(string:"https://secret:password@example.test/start"),destination:URL(fileURLWithPath:"/private-parent/Annual.pdf"))
        record.receivedResponse(url:URL(string:"https://cdn.example.test/final"),mimeType:"application/pdf",expectedBytes:12)
        for query in [" report ","ANNUAL.PDF","example.test/start","cdn.example.test/final",""] {XCTAssertTrue(record.matchesSearch(query),query)}
        for query in ["secret","password","private-parent","missing"] {XCTAssertFalse(record.matchesSearch(query),query)}
    }
}
