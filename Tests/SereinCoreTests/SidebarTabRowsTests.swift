import XCTest
@testable import SereinCore

final class SidebarTabRowsTests:XCTestCase {
    func testPinnedJoinedGroupsRespectFolderVisibilityAndCollapsedSidebar() throws {
        var s=BrowserWindowState();let a=s.selectedTabID!,b=s.newTab(),c=s.newTab()
        let folder=try XCTUnwrap(s.createFolder(name:"Pair",tabIDs:[a,b]))
        s.setSplitTabs([a,b]);s.select(a)
        XCTAssertEqual(s.pinnedSidebarDisplayRows.map(\.tabIDs),[[],[a,b]])
        XCTAssertEqual(s.pinnedSidebarDisplayRows.last?.depth,1)
        s.toggleFolder(folder)
        XCTAssertEqual(s.pinnedSidebarDisplayRows.map(\.tabIDs),[[],[a]])
        s.toggleFolder(folder);s.sidebar = .collapsed
        XCTAssertEqual(s.pinnedSidebarDisplayRows.map(\.tabIDs),[[],[a],[b]])
        s.sidebar = .expanded;s.select(c)
        XCTAssertEqual(s.pinnedSidebarDisplayRows.map(\.tabIDs),[[],[a,b]])
    }
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
    func testKeyboardNeighborsStopAtEdgesAndExcludeHiddenRows() throws {
        var state=BrowserWindowState();let a=state.selectedTabID!,b=state.newTab(select:false),c=state.newTab(select:false)
        let folder=try XCTUnwrap(state.createFolder(name:"Research",tabIDs:[a,b]))
        state.toggleFolder(folder)
        XCTAssertEqual(state.sidebarTabIDs,[a,c])
        XCTAssertEqual(state.sidebarNeighbor(of:a,direction:-1),a)
        XCTAssertEqual(state.sidebarNeighbor(of:a,direction:1),c)
        XCTAssertEqual(state.sidebarNeighbor(of:c,direction:1),c)
        XCTAssertNil(state.sidebarNeighbor(of:b,direction:1))
        XCTAssertNil(state.sidebarNeighbor(of:a,direction:0))
        _=state.addWorkspace(name:"Other")
        XCTAssertNil(state.sidebarNeighbor(of:a,direction:1))
    }
    func testKeyboardRangeExtendsAndContractsThroughRenderedOrder() {
        var state=BrowserWindowState();let a=state.selectedTabID!,b=state.newTab(select:false),c=state.newTab(select:false)
        var selection=TabSelection();selection.selectOnly(a)
        selection.range(to:state.sidebarNeighbor(of:a,direction:1)!,in:state.sidebarTabIDs)
        XCTAssertEqual(selection.ids,Set([a,b]))
        selection.range(to:state.sidebarNeighbor(of:b,direction:1)!,in:state.sidebarTabIDs)
        XCTAssertEqual(selection.ids,Set([a,b,c]))
        selection.range(to:state.sidebarNeighbor(of:c,direction:-1)!,in:state.sidebarTabIDs)
        XCTAssertEqual(selection.ids,Set([a,b]));XCTAssertEqual(selection.anchor,a)
    }
}
