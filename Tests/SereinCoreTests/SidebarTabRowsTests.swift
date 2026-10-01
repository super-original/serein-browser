import XCTest
@testable import SereinCore

final class SidebarTabRowsTests:XCTestCase {
    func testJoinedSplitKeepsEveryTabAndItsOriginalIndexOrder() throws {
        var state=BrowserWindowState();let a=state.selectedTabID!,b=state.newTab(select:false),c=state.newTab(select:false),d=state.newTab(select:false)
        XCTAssertTrue(state.setSplitTabs([c,b]))
        XCTAssertEqual(state.regularSidebarRows.map(\.tabIDs),[[a],[b,c],[d]])
        XCTAssertEqual(state.regularSidebarRows.flatMap(\.tabIDs),state.visibleTabs.map(\.id))
        XCTAssertEqual(state.sidebarTabIDs,[a,b,c,d])
        state.select(c);XCTAssertEqual(state.regularSidebarRows.map(\.tabIDs),[[a],[b,c],[d]])
        XCTAssertEqual(try SavedSession.decode(SavedSession(windows:[state]).encoded()).windows[0].regularSidebarRows,state.regularSidebarRows)
        state.close(b);XCTAssertEqual(state.regularSidebarRows.map(\.tabIDs),[[a],[c],[d]])
    }
    func testSeparatedMixedCategoryAndCollapsedMembersRemainReachable() throws {
        var state=BrowserWindowState();let a=state.selectedTabID!,b=state.newTab(select:false),c=state.newTab(select:false)
        XCTAssertTrue(state.setSplitTabs([a,c]));XCTAssertEqual(state.regularSidebarRows.map(\.tabIDs),[[a],[b],[c]])
        state.setKind(a,.pinned);XCTAssertTrue(state.setSplitTabs([a,b]))
        XCTAssertEqual(state.regularSidebarRows.map(\.tabIDs),[[b],[c]])
        XCTAssertTrue(state.setSplitTabs([b,c]));state.sidebar = .collapsed
        XCTAssertEqual(state.regularSidebarRows.map(\.tabIDs),[[b],[c]])
        state.sidebar = .expanded;XCTAssertEqual(state.regularSidebarRows.map(\.tabIDs),[[b,c]])
        _=state.addWorkspace(name:"Other");XCTAssertFalse(state.regularSidebarRows.flatMap(\.tabIDs).contains(b))
    }
}
