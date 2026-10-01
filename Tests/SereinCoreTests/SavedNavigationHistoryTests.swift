import XCTest
@testable import SereinCore

final class SavedNavigationHistoryTests:XCTestCase {
    private func window(privateMode:Bool=false)->BrowserWindowState {
        var value=BrowserWindowState(isPrivate:privateMode);value.tabs[0].url="https://example.org/page";return value
    }
    private func record(_ window:BrowserWindowState,state:Data=Data([1,2,3]))->SavedNavigationHistory {
        .init(windowID:window.id,tabID:window.tabs[0].id,url:window.tabs[0].url,engine:"fixture-engine",state:state)
    }
    func testRoundTripAndLegacyURLOnlySession() throws {
        let normal=window(),history=record(normal)
        let restored=try SavedSession.decode(SavedSession(windows:[normal],navigationHistory:[history]).encoded())
        XCTAssertEqual(restored.navigationHistory?.first?.state,Data([1,2,3]))
        XCTAssertEqual(restored.navigationHistory?.first?.tabID,normal.tabs[0].id)
        let legacy=try SavedSession.decode(SavedSession(windows:[normal]).encoded())
        XCTAssertNil(legacy.navigationHistory)
    }
    func testPrivateAndMismatchedRecordsAreExcludedAtEncodingBoundary() throws {
        let normal=window(),privateWindow=window(privateMode:true)
        var saved=SavedSession(windows:[normal])
        saved.windows.append(privateWindow)
        let wrong=SavedNavigationHistory(windowID:normal.id,tabID:normal.tabs[0].id,url:"https://example.org/stale",engine:"fixture",state:Data([1]))
        saved.navigationHistory=[record(privateWindow),wrong,record(normal)]
        let decoded=try SavedSession.decode(saved.encoded())
        XCTAssertEqual(decoded.windows.count,1)
        XCTAssertEqual(decoded.navigationHistory?.count,1)
        XCTAssertEqual(decoded.navigationHistory?.first?.windowID,normal.id)
    }
    func testCredentialURLsAndOversizedEmptyDuplicateRecordsAreRejected() {
        let normal=window()
        var credentials=window();credentials.tabs[0].url="https://user:password@example.org/"
        let records=[record(credentials),record(normal,state:Data()),record(normal,state:Data(repeating:0,count:2*1024*1024+1)),record(normal),record(normal)]
        let saved=SavedSession(windows:[normal,credentials],navigationHistory:records)
        XCTAssertEqual(saved.navigationHistory?.count,1)
        XCTAssertEqual(saved.navigationHistory?.first?.tabID,normal.tabs[0].id)
    }
    func testCorruptBytesAreDiscardedWithoutLosingWindow() throws {
        let normal=window()
        let data=try SavedSession(windows:[normal],navigationHistory:[record(normal)]).encoded()
        var json=try XCTUnwrap(JSONSerialization.jsonObject(with:data) as? [String:Any])
        var entries=try XCTUnwrap(json["navigationHistory"] as? [[String:Any]])
        entries[0]["state"]=Data([9,8,7]).base64EncodedString();json["navigationHistory"]=entries
        let restored=try SavedSession.decode(JSONSerialization.data(withJSONObject:json))
        XCTAssertNil(restored.navigationHistory)
        XCTAssertEqual(restored.windows.first?.tabs.first?.url,normal.tabs[0].url)
    }
    func testMalformedOptionalStateKeepsURLSession() throws {
        let normal=window()
        let data=try SavedSession(windows:[normal]).encoded()
        var json=try XCTUnwrap(JSONSerialization.jsonObject(with:data) as? [String:Any])
        json["navigationHistory"]=[["state":"not-base64"]]
        let restored=try SavedSession.decode(JSONSerialization.data(withJSONObject:json))
        XCTAssertNil(restored.navigationHistory)
        XCTAssertEqual(restored.windows.first?.id,normal.id)
    }
    func testTotalPayloadAndSessionReadBound() throws {
        let windows=(0..<10).map{_ in window()}
        let records=windows.map{record($0,state:Data(repeating:0,count:2*1024*1024))}
        let saved=SavedSession(windows:windows,navigationHistory:records)
        XCTAssertEqual(saved.navigationHistory?.count,8)
        XCTAssertThrowsError(try SavedSession.decode(Data(repeating:32,count:32*1024*1024+1)))
    }
}
