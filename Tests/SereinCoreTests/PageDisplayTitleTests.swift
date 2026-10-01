import XCTest
@testable import SereinCore

final class PageDisplayTitleTests:XCTestCase {
    func testUnloadedTabAlreadyHasSafeURLFallbackAndExplicitTitleWins() {
        var state=BrowserWindowState()
        let id=state.newTab(url:"https://name:secret@example.test/research.html?token=private",select:false)
        XCTAssertEqual(state.tabs.first{$0.id==id}?.title,"research.html")
        XCTAssertEqual(state.selectedTab?.title,"New Tab")
        XCTAssertEqual(BrowserTab(workspaceID:state.activeWorkspaceID,url:"https://example.test",title:"New Tab").title,"New Tab")
    }
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
