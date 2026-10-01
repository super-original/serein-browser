import XCTest
@testable import SereinCore

final class SavedSplitGroupTests:XCTestCase {
    func testIndependentGroupsRetainLayoutDividersAndSidebarAcrossSelection() {
        var s=BrowserWindowState();let a=s.selectedTabID!,b=s.newTab(),c=s.newTab(),d=s.newTab()
        s.setSplitTabs([a,b]);s.setSplitLayout(.rows);s.setSplitFraction(0.37,at:0)
        s.select(c);s.setSplitTabs([c,d]);s.setSplitLayout(.columns);s.setSplitFraction(0.62,at:0)
        XCTAssertEqual(s.regularSidebarRows.map(\.tabIDs),[[a,b],[c,d]])
        s.select(b);XCTAssertEqual(s.splitTabIDs,[a,b]);XCTAssertEqual(s.selectedTabID,b)
        XCTAssertEqual(s.resolvedSplitLayout,.rows);XCTAssertEqual(s.splitFraction(at:0),0.37)
        s.select(d);XCTAssertEqual(s.splitTabIDs,[c,d]);XCTAssertEqual(s.resolvedSplitLayout,.columns)
        XCTAssertEqual(s.splitFraction(at:0),0.62);XCTAssertEqual(s.splitGroups.count,2)
    }
    func testInactiveGroupsRoundTripAndExplicitUnsplitOnlyRemovesActive() throws {
        var s=BrowserWindowState();let a=s.selectedTabID!,b=s.newTab(),c=s.newTab(),d=s.newTab()
        s.setSplitTabs([a,b]);s.setSplitFraction(0.31,at:0);s.select(c);s.setSplitTabs([c,d])
        var restored=try SavedSession.decode(SavedSession(windows:[s]).encoded()).windows[0]
        restored.clearSplit();XCTAssertEqual(restored.splitGroups.count,1)
        restored.select(a);XCTAssertEqual(restored.splitTabIDs,[a,b]);XCTAssertEqual(restored.splitFraction(at:0),0.31)
        restored.select(c);XCTAssertTrue(restored.splitTabIDs.isEmpty)
        restored.select(d);XCTAssertTrue(restored.splitTabIDs.isEmpty)
    }
    func testNewTabGlanceAndCloseRestoreOwnerGroup() {
        var s=BrowserWindowState();let a=s.selectedTabID!,b=s.newTab();s.setSplitTabs([a,b])
        let blank=s.newTab();XCTAssertTrue(s.splitTabIDs.isEmpty);s.select(a)
        XCTAssertEqual(s.splitTabIDs,[a,b])
        let glance=s.openGlance(url:"https://example.com",from:a)!
        XCTAssertTrue(s.splitTabIDs.isEmpty);s.close(glance)
        XCTAssertEqual(s.splitTabIDs,[a,b]);XCTAssertEqual(s.selectedTabID,a)
        s.close(blank);XCTAssertEqual(s.splitTabIDs,[a,b])
    }
    func testClosingOrMovingInactiveMembersRepairsGroups() {
        var s=BrowserWindowState();let original=s.activeWorkspaceID
        let a=s.selectedTabID!,b=s.newTab(),c=s.newTab(),d=s.newTab()
        s.setSplitTabs([a,b,c]);s.setSplitFraction(0.3,at:0);s.select(d);s.close(c)
        XCTAssertEqual(s.inactiveSplitGroups?.first?.tabIDs,[a,b]);XCTAssertNil(s.inactiveSplitGroups?.first?.fractions)
        let other=s.addWorkspace(name:"Other");s.switchWorkspace(original);s.select(d)
        s.moveToWorkspace(b,other);XCTAssertTrue(s.splitGroups.isEmpty)
        s.select(a);XCTAssertTrue(s.splitTabIDs.isEmpty)
    }
    func testRegroupingClaimsMembersWithoutDuplicatingOwnership() {
        var s=BrowserWindowState();let a=s.selectedTabID!,b=s.newTab(),c=s.newTab(),d=s.newTab()
        s.setSplitTabs([a,b]);s.select(c);s.setSplitTabs([c,d]);s.setSplitTabs([a,c])
        XCTAssertEqual(s.splitGroups.count,1);XCTAssertEqual(s.splitTabIDs,[a,c])
        s.select(b);XCTAssertTrue(s.splitTabIDs.isEmpty)
    }
    func testRepairRejectsInvalidWorkspaceOverlapsAndPreviewMembers() {
        var s=BrowserWindowState();let a=s.selectedTabID!,b=s.newTab(),c=s.newTab(),d=s.newTab()
        s.setSplitTabs([a,b])
        s.inactiveSplitGroups=[.init(workspaceID:UUID(),tabIDs:[c,d],layout:.grid),
            .init(workspaceID:s.activeWorkspaceID,tabIDs:[a,c,d,c,UUID()],layout:.rows,fractions:[.nan,2,-1]),
            .init(workspaceID:s.activeWorkspaceID,tabIDs:[c,d],layout:.columns)]
        s.repair();XCTAssertEqual(s.inactiveSplitGroups?.count,1)
        XCTAssertEqual(s.inactiveSplitGroups?.first?.tabIDs,[c,d]);XCTAssertNil(s.inactiveSplitGroups?.first?.fractions)
    }
    func testRemovingWorkspacePreservesMigratedGroupsAndLegacyDecoding() throws {
        var s=BrowserWindowState();let first=s.activeWorkspaceID,a=s.selectedTabID!,b=s.newTab()
        s.setSplitTabs([a,b]);let second=s.addWorkspace(name:"Other");s.removeWorkspace(first)
        s.select(a);XCTAssertEqual(s.splitTabIDs,[a,b]);XCTAssertEqual(s.activeWorkspaceID,second)
        var json=try XCTUnwrap(JSONSerialization.jsonObject(with:JSONEncoder().encode(s)) as? [String:Any])
        json.removeValue(forKey:"inactiveSplitGroups")
        var old=try JSONDecoder().decode(BrowserWindowState.self,from:JSONSerialization.data(withJSONObject:json))
        old.repair();XCTAssertEqual(old.splitTabIDs,[a,b]);XCTAssertNil(old.inactiveSplitGroups)
    }
}
