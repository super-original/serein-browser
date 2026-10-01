import XCTest
@testable import SereinCore

final class SplitGridTests:XCTestCase {
    func testGridKeepsOrderAcrossFocusAndRejectsFifthPane() {
        var state=BrowserWindowState()
        let a=state.selectedTabID!,b=state.newTab(),c=state.newTab(),d=state.newTab(),e=state.newTab()
        state.select(a);XCTAssertTrue(state.setSplitTabs([a,b,c,d]))
        XCTAssertEqual(state.splitTabIDs,[a,b,c,d])
        state.select(d);XCTAssertFalse(state.setSplitTabs([a,b,c,d,e]))
        XCTAssertEqual(state.splitTabIDs,[a,b,c,d]);XCTAssertEqual(state.selectedTabID,d)
        state.select(e);XCTAssertTrue(state.splitTabIDs.isEmpty)
    }
    func testClosingFocusedPaneRetainsRemainingGrid() {
        var state=BrowserWindowState()
        let a=state.selectedTabID!,b=state.newTab(),c=state.newTab(),d=state.newTab()
        XCTAssertTrue(state.setSplitTabs([a,b,c,d]));state.select(c);state.close(c)
        XCTAssertEqual(state.splitTabIDs,[a,b,d]);XCTAssertEqual(state.selectedTabID,a)
        state.close(a);XCTAssertEqual(state.splitTabIDs,[b,d]);XCTAssertEqual(state.selectedTabID,b)
        state.close(d);XCTAssertTrue(state.splitTabIDs.isEmpty);XCTAssertNil(state.additionalSplitTabIDs)
    }
    func testMovingPaneToAnotherWorkspaceRetainsOtherPanes() {
        var state=BrowserWindowState();let original=state.activeWorkspaceID
        let other=state.addWorkspace(name:"Other");state.switchWorkspace(original)
        let a=state.selectedTabID!,b=state.newTab(),c=state.newTab()
        XCTAssertTrue(state.setSplitTabs([a,b,c]));state.select(c)
        state.moveToWorkspace(c,other)
        XCTAssertEqual(state.splitTabIDs,[a,b]);XCTAssertEqual(state.selectedTabID,a)
        state.switchWorkspace(other);XCTAssertTrue(state.splitTabIDs.isEmpty);XCTAssertNil(state.additionalSplitTabIDs)
    }
    func testInvalidCompositionDoesNotMutateExistingSplit() {
        var state=BrowserWindowState();let a=state.selectedTabID!,b=state.newTab()
        state.split(with:a);let previous=state
        XCTAssertFalse(state.setSplitTabs([a,a]));XCTAssertFalse(state.setSplitTabs([a,UUID()]))
        XCTAssertEqual(state,previous);XCTAssertEqual(state.splitTabIDs,[b,a])
    }
    func testLegacySessionWithoutAdditionalPanesStillDecodes() throws {
        var state=BrowserWindowState();let a=state.selectedTabID!,b=state.newTab();state.split(with:a)
        var json=try XCTUnwrap(JSONSerialization.jsonObject(with:JSONEncoder().encode(state)) as? [String:Any])
        json.removeValue(forKey:"additionalSplitTabIDs")
        var decoded=try JSONDecoder().decode(BrowserWindowState.self,from:JSONSerialization.data(withJSONObject:json))
        decoded.repair();XCTAssertEqual(decoded.splitTabIDs,[b,a])
    }
    func testGridRoundTripAndCorruptExtraPaneRepair() throws {
        var state=BrowserWindowState();let a=state.selectedTabID!,b=state.newTab(),c=state.newTab(),d=state.newTab()
        XCTAssertTrue(state.setSplitTabs([a,b,c,d]));state.select(d)
        let decoded=try SavedSession.decode(SavedSession(windows:[state]).encoded()).windows[0]
        XCTAssertEqual(decoded.splitTabIDs,[a,b,c,d]);XCTAssertEqual(decoded.selectedTabID,d)
        state.additionalSplitTabIDs=[a,UUID(),c,d]
        state.repair();XCTAssertEqual(state.splitTabIDs,[a,b,c,d])
    }
    func testDividerFractionsSurviveSessionButResetForNewComposition() throws {
        var state=BrowserWindowState();let a=state.selectedTabID!,b=state.newTab(),c=state.newTab()
        XCTAssertTrue(state.setSplitTabs([a,b]));state.setSplitFraction(0.37,at:0)
        let restored=try SavedSession.decode(SavedSession(windows:[state]).encoded()).windows[0]
        XCTAssertEqual(restored.splitFraction(at:0),0.37)
        XCTAssertTrue(state.setSplitTabs([a,b]));XCTAssertEqual(state.splitFraction(at:0),0.37)
        XCTAssertTrue(state.setSplitTabs([a,b,c]));XCTAssertEqual(state.splitFraction(at:0),0.5)
        state.clearSplit();XCTAssertNil(state.splitFractions)
    }
    func testDividerRepairBoundsInvalidAndLegacyValues() {
        var state=BrowserWindowState();let a=state.selectedTabID!,b=state.newTab();state.setSplitTabs([a,b])
        XCTAssertEqual(state.splitFraction(at:0),0.5)
        state.splitFractions=[.nan,-5,5,0.2];state.repair()
        XCTAssertEqual(state.splitFractions,[0.5,0,1])
        state.setSplitFraction(.infinity,at:0);state.setSplitFraction(0.2,at:-1)
        XCTAssertEqual(state.splitFractions,[0.5,0,1])
    }

    func testArrangementKeepsPaneIdentityAndFocusAndResetsOnlyOnChange() {
        var state=BrowserWindowState();let a=state.selectedTabID!,b=state.newTab(),c=state.newTab(),d=state.newTab()
        state.setSplitTabs([a,b,c,d]);state.select(c)
        state.setSplitLayout(.rows)
        XCTAssertEqual(state.splitTabIDs,[a,b,c,d]);XCTAssertEqual(state.selectedTabID,c)
        XCTAssertEqual((0..<3).map{state.splitFraction(at:$0)},[0.25,0.5,0.75])
        state.setSplitFraction(0.3,at:0);state.setSplitLayout(.rows)
        XCTAssertEqual(state.splitFraction(at:0),0.3)
        state.setSplitLayout(.columns);XCTAssertEqual(state.splitFraction(at:0),0.25)
        state.setSplitLayout(.grid);XCTAssertEqual(state.splitFraction(at:0),0.5)
    }
    func testArrangementPersistsAndLegacyDefaultsToGrid() throws {
        var state=BrowserWindowState();let a=state.selectedTabID!,b=state.newTab(),c=state.newTab()
        state.setSplitTabs([a,b,c]);state.setSplitLayout(.columns);state.setSplitFraction(0.4,at:0)
        let restored=try SavedSession.decode(SavedSession(windows:[state]).encoded()).windows[0]
        XCTAssertEqual(restored.resolvedSplitLayout,.columns);XCTAssertEqual(restored.splitFraction(at:0),0.4)
        var json=try XCTUnwrap(JSONSerialization.jsonObject(with:JSONEncoder().encode(state)) as? [String:Any])
        json.removeValue(forKey:"splitLayout");json.removeValue(forKey:"splitFractions")
        let legacy=try JSONDecoder().decode(BrowserWindowState.self,from:JSONSerialization.data(withJSONObject:json))
        XCTAssertEqual(legacy.resolvedSplitLayout,.grid);XCTAssertEqual(legacy.splitFraction(at:0),0.5)
    }
    func testArrangementSurvivesPaneRemovalUntilSplitEnds() {
        var state=BrowserWindowState();let a=state.selectedTabID!,b=state.newTab(),c=state.newTab()
        state.setSplitTabs([a,b,c]);state.setSplitLayout(.rows);state.close(c)
        XCTAssertEqual(state.resolvedSplitLayout,.rows);XCTAssertEqual(state.splitTabIDs,[a,b]);XCTAssertEqual(state.splitFraction(at:0),0.5)
        state.close(b);XCTAssertNil(state.splitLayout);XCTAssertNil(state.splitFractions)
        state.setSplitLayout(.columns);XCTAssertNil(state.splitLayout)
    }

}
