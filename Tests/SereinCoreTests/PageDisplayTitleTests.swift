import XCTest
@testable import SereinCore

final class PageDisplayTitleTests:XCTestCase {
    func testUntitledDocumentsUseUsefulNamesWithoutURLCredentialsOrQuery() {
        XCTAssertEqual(PageDisplayTitle.resolve(nil,url:URL(string:"https://name:secret@example.test/formatter.json?token=value#part")),"formatter.json")
        XCTAssertEqual(PageDisplayTitle.resolve("  ",url:URL(string:"https://example.test/")),"example.test")
        XCTAssertEqual(PageDisplayTitle.resolve(nil,url:URL(fileURLWithPath:"/tmp/Research Notes.html")),"Research Notes.html")
        XCTAssertEqual(PageDisplayTitle.resolve(nil,url:URL(string:"data:text/html,private-payload")),"Untitled Page")
        XCTAssertEqual(PageDisplayTitle.resolve(nil,url:URL(string:"about:blank")),"New Tab")
    }
    func testPageTitlesRemainAuthoritativeAndURLTitlesRedactUserinfo() {
        let url=URL(string:"https://name:secret@example.test/page")!
        XCTAssertEqual(PageDisplayTitle.resolve("  Research notes  ",url:url),"Research notes")
        XCTAssertEqual(PageDisplayTitle.resolve(url.absoluteString,url:url),"https://example.test/page")
        XCTAssertEqual(PageDisplayTitle.resolve(nil,url:nil),"New Tab")
    }
}
