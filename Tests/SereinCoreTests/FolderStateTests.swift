import XCTest
@testable import SereinCore
final class FolderStateTests:XCTestCase {
    func testCreationPinsAndCollapseRetainsOnlyActiveChild() throws {
        var state=BrowserWindowState();let a=state.selectedTabID!,b=state.newTab(url:"https://example.test/b",select:false)
        let folder=try XCTUnwrap(state.createFolder(name:"Research",tabIDs:[a,b]))
        XCTAssertEqual(state.visibleTabs.map(\.id),[a,b]);XCTAssertTrue(state.tabs.allSatisfy{$0.kind == .pinned})
        XCTAssertEqual(state.pinnedSidebarRows.map(\.id),[folder,a,b])
        state.toggleFolder(folder);XCTAssertEqual(state.pinnedSidebarRows.map(\.id),[folder,a])
        state.select(b);XCTAssertEqual(state.pinnedSidebarRows.map(\.id),[folder,b])
        let preview=try XCTUnwrap(state.openGlance(url:"https://example.test/preview",from:b))
        XCTAssertEqual(state.selectedTabID,preview);XCTAssertEqual(state.pinnedSidebarRows.map(\.id),[folder,b])
    }
    func testFolderMovePreservesPinnedHomeAndRejectsCyclesAndExcessDepth() throws {
        var state=BrowserWindowState();let tab=state.selectedTabID!
        state.setKind(tab,.pinned);let home=state.tabs[0].homeURL;state.tabs[0].url="https://example.test/changed"
        let root=try XCTUnwrap(state.createFolder(name:"Root",tabIDs:[tab]))
        XCTAssertEqual(state.tabs[0].homeURL,home)
        var deepest=root
        for level in 2...5 {deepest=try XCTUnwrap(state.createFolder(name:"Level \(level)",parentID:deepest))}
        let before=state
        XCTAssertNil(state.createFolder(name:"Too deep",parentID:deepest));XCTAssertFalse(state.moveFolder(root,into:deepest));XCTAssertEqual(state,before)
        let other=try XCTUnwrap(state.createFolder(name:"Other"))
        XCTAssertFalse(state.moveFolder(root,into:other));XCTAssertTrue(state.moveFolder(deepest,into:other))
        XCTAssertEqual(state.folderDepth(deepest),2)
    }
    func testUnpackKeepsNestedFoldersTabsAndOrder() throws {
        var state=BrowserWindowState();let a=state.selectedTabID!,b=state.newTab(select:false)
        let root=try XCTUnwrap(state.createFolder(name:"Root",tabIDs:[a]))
        let child=try XCTUnwrap(state.createFolder(name:"Child",tabIDs:[b],parentID:root))
        state.unpackFolder(root)
        XCTAssertNil(state.folder(root));XCTAssertNil(state.folder(child)?.parentID)
        XCTAssertNil(state.tabs.first{$0.id==a}?.folderID);XCTAssertEqual(state.tabs.first{$0.id==b}?.folderID,child)
        XCTAssertEqual(state.pinnedSidebarRows.map(\.id),[a,child,b]);XCTAssertEqual(state.tabs.count,2)
    }
    func testMoveAcrossWorkspacesKeepsTreeAndRepairsOldSelection() throws {
        var state=BrowserWindowState();let original=state.activeWorkspaceID,a=state.selectedTabID!
        let root=try XCTUnwrap(state.createFolder(name:"Root",tabIDs:[a]))
        let other=state.addWorkspace(name:"Other");state.switchWorkspace(original)
        state.moveFolderToWorkspace(root,other)
        XCTAssertEqual(state.folder(root)?.workspaceID,other);XCTAssertEqual(state.tabs.first{$0.id==a}?.workspaceID,other)
        XCTAssertNotEqual(state.selectedTabID,a);XCTAssertEqual(state.activeWorkspaceID,original)
        state.switchWorkspace(other);XCTAssertTrue(state.visibleTabs.contains{$0.id==a})
        state.removeWorkspace(other);XCTAssertEqual(state.folder(root)?.workspaceID,original)
    }
    func testSessionRoundTripAndLegacyDecode() throws {
        var state=BrowserWindowState();let folder=try XCTUnwrap(state.createFolder(name:"Saved",tabIDs:[state.selectedTabID!]))
        state.toggleFolder(folder)
        let data=try SavedSession(windows:[state]).encoded()
        XCTAssertEqual(try SavedSession.decode(data).windows.first,state)
        var json=try XCTUnwrap(JSONSerialization.jsonObject(with:data) as? [String:Any])
        var windows=try XCTUnwrap(json["windows"] as? [[String:Any]])
        windows[0].removeValue(forKey:"folders");windows[0].removeValue(forKey:"pinnedOrder")
        var tabs=try XCTUnwrap(windows[0]["tabs"] as? [[String:Any]])
        for i in tabs.indices {tabs[i].removeValue(forKey:"folderID")};windows[0]["tabs"]=tabs;json["windows"]=windows
        let legacy=try SavedSession.decode(JSONSerialization.data(withJSONObject:json)).windows[0]
        XCTAssertNil(legacy.folders);XCTAssertEqual(legacy.visibleTabs.count,1)
    }
    func testRepairRejectsCyclesDuplicateIDsAndInvalidMembership() throws {
        var state=BrowserWindowState();let tab=state.selectedTabID!
        let a=try XCTUnwrap(state.createFolder(name:"A",tabIDs:[tab])),b=try XCTUnwrap(state.createFolder(name:"B",parentID:a))
        state.folders?[0].parentID=b
        state.folders?.append(TabFolder(id:a,workspaceID:state.activeWorkspaceID))
        state.folders?.append(TabFolder(id:tab,workspaceID:state.activeWorkspaceID))
        state.tabs[0].kind = .regular
        state.repair()
        XCTAssertEqual(state.folders?.count,2);XCTAssertNil(state.tabs[0].folderID)
        XCTAssertTrue((state.folders ?? []).allSatisfy{state.folderDepth($0.id)<=2})
        XCTAssertEqual(state.visibleTabs.map(\.id),[tab])
    }
    func testCloseReopenAndDeletedFolderDoNotCreateOrphans() throws {
        var state=BrowserWindowState();let tab=state.selectedTabID!
        let folder=try XCTUnwrap(state.createFolder(name:"A",tabIDs:[tab]))
        state.close(tab);XCTAssertEqual(state.reopen(),tab);XCTAssertEqual(state.tabs.first{$0.id==tab}?.folderID,folder)
        state.close(tab);state.removeEmptyFolderTree(folder)
        XCTAssertEqual(state.reopen(),tab);XCTAssertNil(state.tabs.first{$0.id==tab}?.folderID)
    }
    func testInvalidSelectionDoesNotPartiallyPinTabs() {
        var state=BrowserWindowState();let essential=state.selectedTabID!,regular=state.newTab()
        state.setKind(essential,.essential);let before=state
        XCTAssertNil(state.createFolder(name:"Invalid",tabIDs:[regular,essential]));XCTAssertEqual(state,before)
    }
    func testRootOrderingSurvivesOperationsInAnotherWorkspace() throws {
        var state=BrowserWindowState();let first=state.activeWorkspaceID
        let a=try XCTUnwrap(state.createFolder(name:"A")),b=try XCTUnwrap(state.createFolder(name:"B"))
        let second=state.addWorkspace(name:"Second")
        let c=try XCTUnwrap(state.createFolder(name:"C")),d=try XCTUnwrap(state.createFolder(name:"D"))
        XCTAssertTrue(state.shiftPinnedItem(d,by:-1));XCTAssertFalse(state.shiftPinnedItem(d,by:-1))
        state.switchWorkspace(first);state.unpackFolder(a)
        XCTAssertEqual(state.pinnedItemIDs(),[b])
        state.switchWorkspace(second);XCTAssertEqual(state.pinnedItemIDs(),[d,c])
    }
    func testConvertFolderPreservesNestedOrderSelectionAndOtherWorkspace() throws {
        var state=BrowserWindowState();let old=state.activeWorkspaceID,a=state.selectedTabID!
        let b=state.newTab(),outside=state.newTab()
        let root=try XCTUnwrap(state.createFolder(name:"Research",tabIDs:[a]))
        let child=try XCTUnwrap(state.createFolder(name:"Reading",tabIDs:[b],parentID:root))
        state.select(b)
        let new=try XCTUnwrap(state.convertFolderToWorkspace(root))
        XCTAssertEqual(state.activeWorkspaceID,new);XCTAssertEqual(state.selectedTabID,b)
        XCTAssertEqual(state.workspaces.first{$0.id==new}?.name,"Research")
        XCTAssertNil(state.folder(root));XCTAssertNil(state.folder(child)?.parentID)
        XCTAssertEqual(state.folder(child)?.workspaceID,new)
        XCTAssertEqual(state.pinnedItemIDs(),[a,child]);XCTAssertEqual(state.folderTabIDs(child),[b])
        XCTAssertEqual(state.tabs.count,3);XCTAssertEqual(state.tabs.first{$0.id==outside}?.workspaceID,old)
        state.switchWorkspace(old);XCTAssertEqual(state.selectedTabID,outside)
        let before=state;XCTAssertNil(state.convertFolderToWorkspace(root));XCTAssertEqual(state,before)
    }
    func testConvertEmptyFolderCreatesUsableWorkspaceWithoutClosingPages() throws {
        var state=BrowserWindowState();let original=state.selectedTabID!
        let folder=try XCTUnwrap(state.createFolder(name:"Empty"))
        let workspace=try XCTUnwrap(state.convertFolderToWorkspace(folder))
        XCTAssertEqual(state.activeWorkspaceID,workspace);XCTAssertNotNil(state.selectedTabID)
        XCTAssertTrue(state.tabs.contains{$0.id==original});XCTAssertNil(state.folder(folder))
        XCTAssertEqual(state.tabs.count,2)
    }

    func testConvertFolderCarriesSelectedGlanceWithoutDetachingIt() throws {
        var state=BrowserWindowState();let owner=state.selectedTabID!
        let folder=try XCTUnwrap(state.createFolder(name:"Preview",tabIDs:[owner]))
        let preview=try XCTUnwrap(state.openGlance(url:"https://example.org",from:owner))
        let workspace=try XCTUnwrap(state.convertFolderToWorkspace(folder))
        XCTAssertEqual(state.selectedTabID,preview);XCTAssertEqual(state.activeGlance?.glanceParentID,owner)
        XCTAssertEqual(state.activeGlance?.workspaceID,workspace);XCTAssertEqual(state.sidebarSelectedTabID,owner)
        XCTAssertEqual(state.tabs.first{$0.id==owner}?.workspaceID,workspace)
    }

    func testCustomIconSurvivesCollapseWorkspaceMoveAndSession() throws {
        var state=BrowserWindowState();let tab=state.selectedTabID!
        let folder=try XCTUnwrap(state.createFolder(name:"Research",tabIDs:[tab]))
        state.folders?[0].userIcon=FolderIcon.science.rawValue
        state.toggleFolder(folder)
        let destination=state.addWorkspace(name:"Science");state.moveFolderToWorkspace(folder,destination)
        let restored=try SavedSession.decode(SavedSession(windows:[state]).encoded()).windows[0]
        XCTAssertEqual(restored.folder(folder)?.resolvedIcon,.science)
        XCTAssertEqual(restored.folderTabIDs(folder),[tab]);XCTAssertEqual(restored.folder(folder)?.workspaceID,destination)
        XCTAssertEqual(restored.folder(folder)?.collapsed,true)
    }
    func testLegacyAndUnknownFolderIconsUseNativeFallback() throws {
        let folder=TabFolder(workspaceID:UUID())
        var json=try XCTUnwrap(JSONSerialization.jsonObject(with:JSONEncoder().encode(folder)) as? [String:Any])
        json.removeValue(forKey:"userIcon")
        let legacy=try JSONDecoder().decode(TabFolder.self,from:JSONSerialization.data(withJSONObject:json))
        XCTAssertNil(legacy.userIcon);XCTAssertNil(legacy.resolvedIcon)
        for value in ["https://example.test/tracker.svg","unknown-future-icon",""] {
            json["userIcon"]=value
            let decoded=try JSONDecoder().decode(TabFolder.self,from:JSONSerialization.data(withJSONObject:json))
            XCTAssertNil(decoded.resolvedIcon);XCTAssertEqual(decoded.id,folder.id)
        }
    }

    func testFolderPlacementBeforeAfterLastAndNestedPersistence() throws {
        var state=BrowserWindowState();let tab=state.selectedTabID!
        let a=try XCTUnwrap(state.createFolder(name:"A",tabIDs:[tab])),b=try XCTUnwrap(state.createFolder(name:"B"))
        let child=try XCTUnwrap(state.createFolder(name:"Child",parentID:a))
        state.folders?[0].userIcon=FolderIcon.star.rawValue
        XCTAssertTrue(state.placeFolder(a,beside:b,after:true));XCTAssertEqual(state.pinnedItemIDs(),[b,a])
        XCTAssertTrue(state.placeFolder(a,beside:b,after:false));XCTAssertEqual(state.pinnedItemIDs(),[a,b])
        XCTAssertTrue(state.placeFolder(child,beside:b,after:true));XCTAssertNil(state.folder(child)?.parentID)
        XCTAssertEqual(state.pinnedItemIDs(),[a,b,child]);XCTAssertEqual(state.folderTabIDs(a),[tab])
        XCTAssertEqual(try SavedSession.decode(SavedSession(windows:[state]).encoded()).windows[0],state)
    }
    func testInvalidFolderPlacementIsAtomic() throws {
        var state=BrowserWindowState();let workspace=state.activeWorkspaceID
        let root=try XCTUnwrap(state.createFolder(name:"Root")),child=try XCTUnwrap(state.createFolder(name:"Child",parentID:root))
        let other=state.addWorkspace(name:"Other"),foreign=try XCTUnwrap(state.createFolder(name:"Foreign"))
        state.switchWorkspace(workspace)
        let before=state
        XCTAssertFalse(state.placeFolder(root,beside:child,after:true))
        XCTAssertFalse(state.placeFolder(root,beside:root,after:false))
        XCTAssertFalse(state.placeFolder(root,beside:foreign,after:true))
        XCTAssertFalse(state.placeFolder(root,beside:UUID(),after:true));XCTAssertEqual(state,before)
        XCTAssertEqual(state.folder(foreign)?.workspaceID,other)
        var deep=root
        for level in 2...5 {deep=try XCTUnwrap(state.createFolder(name:"Level \(level)",parentID:deep))}
        let sibling=try XCTUnwrap(state.createFolder(name:"Sibling"));_=state.createFolder(name:"Nested",parentID:sibling)
        let beforeDepth=state
        XCTAssertFalse(state.placeFolder(sibling,beside:deep,after:true));XCTAssertEqual(state,beforeDepth)
    }

}
