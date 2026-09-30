import XCTest
@testable import SereinCore

final class TabCreationTests:XCTestCase {
    func testCreationHasFinalKindIndexAndOpenerBeforePublication() {
        var state=BrowserWindowState();let opener=state.selectedTabID!
        let tab=state.newTab(url:"https://example.org",select:false,kind:.pinned,index:0,opener:opener)
        XCTAssertEqual(state.tabs.first?.id,tab);XCTAssertEqual(state.tabs.first?.kind,.pinned)
        XCTAssertEqual(state.tabs.first?.homeURL,"https://example.org");XCTAssertEqual(state.tabs.first?.openerTabID,opener)
        XCTAssertEqual(state.selectedTabID,opener)
    }
    func testInsertionClampsBothIntegerExtremes() {
        var state=BrowserWindowState()
        let front=state.newTab(index:Int.min),end=state.newTab(index:Int.max)
        XCTAssertEqual(state.tabs.first?.id,front);XCTAssertEqual(state.tabs.last?.id,end)
    }
    func testOpenerMutationRejectsForeignAndSelfThenClearsOnClose() {
        var state=BrowserWindowState();let first=state.selectedTabID!,second=state.newTab(opener:first)
        let before=state
        XCTAssertFalse(state.setOpener(second,to:second));XCTAssertFalse(state.setOpener(second,to:UUID()));XCTAssertEqual(state,before)
        XCTAssertTrue(state.setOpener(second,to:nil));XCTAssertNil(state.tabs.last?.openerTabID)
        XCTAssertTrue(state.setOpener(second,to:first));state.close(first)
        XCTAssertTrue(state.tabs.contains{$0.id==second});XCTAssertNil(state.tabs.first{$0.id==second}?.openerTabID)
    }
    func testRepairAndReopenDoNotRetainMissingOpeners() throws {
        var state=BrowserWindowState();let parent=state.selectedTabID!,child=state.newTab(opener:parent)
        let restored=try SavedSession.decode(SavedSession(windows:[state]).encoded()).windows[0]
        XCTAssertEqual(restored.tabs.first{$0.id==child}?.openerTabID,parent)
        state.close(child);state.close(parent,remember:false);_=state.reopen()
        XCTAssertNil(state.tabs.first{$0.id==child}?.openerTabID)
        state.tabs[0].openerTabID=state.tabs[0].id;state.repair();XCTAssertNil(state.tabs[0].openerTabID)
    }
}
