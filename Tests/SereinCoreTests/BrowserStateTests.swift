import XCTest
@testable import SereinCore

final class BrowserStateTests: XCTestCase {
    func testClosingSelectedTabUsesNeighborAndReopenRestoresIdentity() {
        var s=BrowserWindowState();let first=s.selectedTabID!;let second=s.newTab(url:"https://example.org");let third=s.newTab()
        s.select(second);s.close(second)
        XCTAssertEqual(s.selectedTabID,third);XCTAssertEqual(s.reopen(),second);XCTAssertEqual(s.selectedTab?.url,"https://example.org");XCTAssertTrue(s.tabs.contains{$0.id==first})
    }
    func testEssentialsCrossWorkspacesButPinnedTabsDoNot() {
        var s=BrowserWindowState();let essential=s.selectedTabID!;s.setKind(essential,.essential)
        let pinned=s.newTab();s.setKind(pinned,.pinned);let other=s.addWorkspace(name:"Research")
        XCTAssertEqual(s.activeWorkspaceID,other);XCTAssertTrue(s.visibleTabs.contains{$0.id==essential});XCTAssertFalse(s.visibleTabs.contains{$0.id==pinned})
    }
    func testSplitCannotReferenceClosedOrInvisibleTab() {
        var s=BrowserWindowState();let a=s.selectedTabID!;let b=s.newTab();s.split(with:a)
        XCTAssertEqual(s.secondaryTabID,a);s.close(a);XCTAssertNil(s.secondaryTabID)
        s.split(with:b);XCTAssertNil(s.secondaryTabID)
    }
    func testPrivateWindowsNeverEncodeEvenIfInjectedAfterInitialization() throws {
        let normal=BrowserWindowState();var privateWindow=BrowserWindowState(isPrivate:true);privateWindow.newTab(url:"https://private.example/secret")
        var session=SavedSession(windows:[normal]);session.windows.append(privateWindow)
        let data=try session.encoded();XCTAssertFalse(String(decoding:data,as:UTF8.self).contains("private.example"))
        XCTAssertEqual(try SavedSession.decode(data).windows.count,1)
    }
    func testRestoreRepairsInvalidSelectionAndDuplicateIDs() throws {
        var s=BrowserWindowState();s.selectedTabID=UUID();s.tabs.append(s.tabs[0]);s.secondaryTabID=UUID();s.sidebarWidth=999
        let restored=try SavedSession.decode(SavedSession(windows:[s]).encoded()).windows[0]
        XCTAssertEqual(restored.tabs.count,1);XCTAssertEqual(restored.selectedTabID,restored.tabs[0].id);XCTAssertNil(restored.secondaryTabID);XCTAssertEqual(restored.sidebarWidth,500)
    }
    func testWorkspaceRemovalKeepsTabsAndCloseLastCreatesBlank() {
        var s=BrowserWindowState();let first=s.selectedTabID!;let old=s.activeWorkspaceID;s.addWorkspace(name:"Second");s.removeWorkspace(old)
        XCTAssertTrue(s.tabs.contains{$0.id==first});XCTAssertEqual(s.workspaces.count,1)
        for tab in s.tabs {s.close(tab.id)}
        XCTAssertEqual(s.visibleTabs.count,1);XCTAssertNotNil(s.selectedTabID)
    }
    func testMovePreservesOrderAndKindBoundaries() {
        var s=BrowserWindowState();let a=s.selectedTabID!;let b=s.newTab();let c=s.newTab();s.move(c,before:a)
        XCTAssertEqual(s.tabs.map(\.id),[c,a,b]);s.setKind(a,.essential);s.move(b,before:a);XCTAssertEqual(s.tabs.map(\.id),[c,a,b])
    }
    func testOriginIncludesSchemeAndPort() throws {
        let a=try XCTUnwrap(SiteOrigin(url:URL(string:"https://EXAMPLE.com/a")!))
        XCTAssertEqual(a,SiteOrigin(url:URL(string:"https://example.com:443/b")!))
        XCTAssertNotEqual(a,SiteOrigin(url:URL(string:"http://example.com")!));XCTAssertNil(SiteOrigin(url:URL(string:"file:///tmp/a")!))
    }
    func testAddressInputCannotExecuteJavaScriptAndEscapesQueries() {
        XCTAssertEqual(AddressResolver.resolve("example.com/a")?.absoluteString,"https://example.com/a")
        XCTAssertEqual(AddressResolver.resolve("localhost:8765")?.scheme,"http")
        XCTAssertEqual(AddressResolver.resolve("javascript:alert(1)")?.host,"duckduckgo.com")
        XCTAssertTrue(AddressResolver.resolve("a & b")!.absoluteString.contains("%26"))
        XCTAssertNil(AddressResolver.resolve(" \n "))
    }
}
