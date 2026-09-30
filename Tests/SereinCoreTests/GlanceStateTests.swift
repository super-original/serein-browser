import XCTest
@testable import SereinCore

final class GlanceStateTests:XCTestCase {
    func testPreviewHidesItsRowAndPreservesOwner() throws {
        var state=BrowserWindowState();let owner=try XCTUnwrap(state.selectedTabID)
        let preview=try XCTUnwrap(state.openGlance(url:"https://example.com/preview",from:owner))
        XCTAssertEqual(state.visibleTabs.map(\.id),[owner]);XCTAssertEqual(state.tabs.count,2)
        XCTAssertEqual(state.selectedTabID,preview);XCTAssertEqual(state.sidebarSelectedTabID,owner)
        XCTAssertNil(state.openGlance(url:"https://example.com/other",from:owner))
        XCTAssertNil(state.openGlance(url:"https://example.com/nested",from:preview))
        state.select(owner);XCTAssertEqual(state.selectedTabID,preview)
    }
    func testClosingPreviewReturnsToOwnerAndClosingOwnerRemovesChild() throws {
        var state=BrowserWindowState();let owner=try XCTUnwrap(state.selectedTabID)
        let other=state.newTab();state.select(owner)
        let preview=try XCTUnwrap(state.openGlance(url:"https://example.com",from:owner))
        XCTAssertEqual(state.closingTabIDs(owner),[preview,owner])
        state.close(preview);XCTAssertEqual(state.selectedTabID,owner)
        _=state.openGlance(url:"https://example.com",from:owner)
        state.close(owner);XCTAssertEqual(state.tabs.map(\.id),[other]);XCTAssertEqual(state.selectedTabID,other)
        let reopened=try XCTUnwrap(state.reopen());XCTAssertNil(state.tabs.first{$0.id==reopened}?.glanceParentID)
    }
    func testExpandAndSplitKeepTheSameTabIdentity() throws {
        var state=BrowserWindowState();let owner=try XCTUnwrap(state.selectedTabID)
        let preview=try XCTUnwrap(state.openGlance(url:"https://example.com",from:owner))
        let beforeInvalidSplit=state
        state.split(with:UUID())
        XCTAssertEqual(state,beforeInvalidSplit)
        state.splitGlance(preview)
        XCTAssertEqual(state.splitTabIDs,[owner,preview]);XCTAssertNil(state.activeGlance)
        XCTAssertEqual(state.selectedTabID,preview);XCTAssertEqual(state.visibleTabs.count,2)
    }
    func testWorkspaceMoveCarriesPreviewWithoutOrphaningIt() throws {
        var state=BrowserWindowState();let owner=try XCTUnwrap(state.selectedTabID),original=state.activeWorkspaceID
        let destination=state.addWorkspace(name:"Research");state.switchWorkspace(original)
        let preview=try XCTUnwrap(state.openGlance(url:"https://example.com",from:owner))
        state.moveToWorkspace(owner,destination)
        XCTAssertEqual(state.tabs.first{$0.id==preview}?.workspaceID,destination)
        XCTAssertNotEqual(state.selectedTabID,preview)
        state.switchWorkspace(destination);state.select(owner);XCTAssertEqual(state.selectedTabID,preview)
    }
    func testSessionRoundTripRetainsValidPreviewButExcludesPrivateWindows() throws {
        var state=BrowserWindowState();let owner=try XCTUnwrap(state.selectedTabID)
        let preview=try XCTUnwrap(state.openGlance(url:"https://example.com",from:owner))
        let restored=try SavedSession.decode(SavedSession(windows:[state,BrowserWindowState(isPrivate:true)]).encoded())
        XCTAssertEqual(restored.windows.count,1);XCTAssertEqual(restored.windows[0].activeGlance?.id,preview)
        XCTAssertEqual(restored.windows[0].sidebarSelectedTabID,owner)
    }
    func testRepairPromotesOrphanPreviewAndRemovesDuplicateOwnership() throws {
        var state=BrowserWindowState();let owner=try XCTUnwrap(state.selectedTabID)
        let preview=try XCTUnwrap(state.openGlance(url:"https://example.com",from:owner))
        var duplicate=BrowserTab(workspaceID:state.activeWorkspaceID);duplicate.glanceParentID=owner;state.tabs.append(duplicate)
        state.repair();XCTAssertNil(state.tabs.first{$0.id==duplicate.id}?.glanceParentID)
        state.tabs.removeAll{$0.id==owner};state.repair()
        XCTAssertNil(state.tabs.first{$0.id==preview}?.glanceParentID)
        XCTAssertTrue(state.visibleTabs.contains{$0.id==state.selectedTabID})
    }
    func testEssentialPreviewDoesNotForceAnotherWorkspace() throws {
        var state=BrowserWindowState();let owner=try XCTUnwrap(state.selectedTabID)
        state.setKind(owner,.essential)
        let second=state.addWorkspace(name:"Research")
        let preview=try XCTUnwrap(state.openGlance(url:"https://example.com",from:owner))
        state.select(owner);state.repair()
        XCTAssertEqual(state.activeWorkspaceID,second);XCTAssertEqual(state.selectedTabID,preview)
        XCTAssertEqual(state.sidebarSelectedTabID,owner)
    }

    func testTabCyclingUsesThePreviewOwnersSidebarPosition() throws {
        var state=BrowserWindowState();let first=try XCTUnwrap(state.selectedTabID)
        let owner=state.newTab(),last=state.newTab();state.select(owner)
        let preview=try XCTUnwrap(state.openGlance(url:"https://example.com",from:owner))
        XCTAssertEqual(state.adjacentVisibleTab(-1),first);XCTAssertEqual(state.adjacentVisibleTab(1),last)
        state.select(last);XCTAssertEqual(state.adjacentVisibleTab(1),first)
        state.select(owner);XCTAssertEqual(state.selectedTabID,preview)
    }

    func testAutomaticPreviewRequiresOptInPinnedOwnerAndDifferentHost() throws {
        var state=BrowserWindowState();let owner=try XCTUnwrap(state.selectedTabID)
        state.tabs[0].url="https://example.com/owner"
        let external=URL(string:"https://other.example/preview")!
        XCTAssertFalse(state.shouldPreviewNewTab(external,from:owner,enabled:true))
        for kind in [TabKind.pinned,.essential] {
            state.setKind(owner,kind)
            XCTAssertFalse(state.shouldPreviewNewTab(external,from:owner,enabled:false))
            XCTAssertTrue(state.shouldPreviewNewTab(external,from:owner,enabled:true))
            XCTAssertFalse(state.shouldPreviewNewTab(URL(string:"http://EXAMPLE.com:8080/path")!,from:owner,enabled:true))
            XCTAssertFalse(state.shouldPreviewNewTab(URL(string:"file:///tmp/page.html")!,from:owner,enabled:true))
            XCTAssertFalse(state.shouldPreviewNewTab(URL(string:"javascript:alert(1)")!,from:owner,enabled:true))
        }
        let preview=try XCTUnwrap(state.openGlance(url:external.absoluteString,from:owner))
        XCTAssertFalse(state.shouldPreviewNewTab(external,from:owner,enabled:true))
        XCTAssertFalse(state.shouldPreviewNewTab(external,from:preview,enabled:true))
    }

    func testReopenParentRestoresItsPreviewAndSanitizesBothURLs() throws {
        var state=BrowserWindowState();let owner=try XCTUnwrap(state.selectedTabID)
        state.tabs[0].url="https://owner:secret@example.com/owner"
        let preview=try XCTUnwrap(state.openGlance(url:"https://preview:secret@example.com/preview",from:owner))
        state.close(owner)
        let data=try SavedSession(windows:[state]).encoded()
        XCTAssertFalse(String(decoding:data,as:UTF8.self).contains("secret"))
        var restored=try XCTUnwrap(SavedSession.decode(data).windows.first)
        XCTAssertEqual(restored.reopen(),owner)
        XCTAssertEqual(restored.activeGlance?.id,preview)
        XCTAssertEqual(restored.activeGlance?.url,"https://example.com/preview")
        XCTAssertEqual(restored.tabs.first{$0.id==owner}?.url,"https://example.com/owner")
    }

}
