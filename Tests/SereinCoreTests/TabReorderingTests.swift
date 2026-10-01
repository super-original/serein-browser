import XCTest
@testable import SereinCore

final class TabReorderingTests:XCTestCase {
    func testMoveAfterLastTabAndBackBeforeFirstPreservesSelection() {
        var state=BrowserWindowState()
        let a=state.selectedTabID!,b=state.newTab(select:false),c=state.newTab(select:false)
        state.move(a,after:c)
        XCTAssertEqual(state.visibleTabs.map(\.id),[b,c,a]);XCTAssertEqual(state.selectedTabID,a)
        state.move(c,after:b)
        XCTAssertEqual(state.visibleTabs.map(\.id),[b,c,a])
        state.move(a,before:b)
        XCTAssertEqual(state.visibleTabs.map(\.id),[a,b,c]);XCTAssertEqual(state.selectedTabID,a)
    }
    func testAfterPlacementTransfersFolderMembershipAndPersistsOrder() throws {
        var state=BrowserWindowState()
        let a=state.selectedTabID!,b=state.newTab(select:false),c=state.newTab(select:false)
        let source=try XCTUnwrap(state.createFolder(name:"Source",tabIDs:[a]))
        let destination=try XCTUnwrap(state.createFolder(name:"Destination",tabIDs:[b,c]))
        state.move(a,after:c)
        XCTAssertEqual(state.folderTabIDs(source),[])
        XCTAssertEqual(state.tabs.first{$0.id==a}?.folderID,destination)
        XCTAssertEqual(state.pinnedItemIDs(in:destination),[b,c,a])
        let restored=try SavedSession.decode(SavedSession(windows:[state]).encoded()).windows[0]
        XCTAssertEqual(restored.pinnedItemIDs(in:destination),[b,c,a])
        state.move(a,before:b)
        XCTAssertEqual(state.pinnedItemIDs(in:destination),[a,b,c])
    }
    func testInvalidAfterTargetsDoNotMutateState() {
        var state=BrowserWindowState()
        let a=state.selectedTabID!,pinned=state.newTab(select:false,kind:.pinned)
        let before=state
        state.move(a,after:a);state.move(a,after:UUID());state.move(a,after:pinned)
        XCTAssertEqual(state,before)
    }
}
