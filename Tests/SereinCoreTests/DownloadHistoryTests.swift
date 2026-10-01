import XCTest
@testable import SereinCore

final class DownloadHistoryTests:XCTestCase {
    func testLegacyMigrationAssignsStableNormalIDsAndExcludesPrivate() throws {
        let first=DownloadRecord(name:"First",phase:.paused),second=DownloadRecord(name:"Second",phase:.complete)
        let secret=DownloadRecord(name:"Private",privateWindowID:UUID())
        let data=try JSONEncoder().encode([first,secret,second])
        let decoded=try DownloadHistory.decode(data)
        XCTAssertTrue(decoded.migrated)
        XCTAssertEqual(decoded.history.records.map(\.browserIdentifier),[1,2])
        XCTAssertEqual(decoded.history.records.map(\.id),[first.id,second.id])
        XCTAssertEqual(decoded.history.records[0].phase,.interrupted)
        let restored=try DownloadHistory.decode(decoded.history.encoded(records:decoded.history.records))
        XCTAssertFalse(restored.migrated)
        XCTAssertEqual(restored.history.records.map(\.browserIdentifier),[1,2])
        XCTAssertEqual(restored.history.nextIdentifier,3)
    }
    func testClearedHistoryNeverReusesEarlierIdentifiers() throws {
        var history=DownloadHistory()
        XCTAssertEqual(try history.allocate(),1)
        XCTAssertEqual(try history.allocate(),2)
        var restored=try DownloadHistory.decode(history.encoded(records:[])).history
        XCTAssertEqual(try restored.allocate(),3)
        XCTAssertTrue(restored.records.isEmpty)
    }
    func testPrivateInjectionCannotReachSerializedHistory() throws {
        var history=DownloadHistory()
        var normal=DownloadRecord(name:"Normal",phase:.complete);normal.browserIdentifier=try history.allocate()
        var secret=DownloadRecord(name:"Private sentinel",privateWindowID:UUID());secret.browserIdentifier=777
        let data=try history.encoded(records:[normal,secret])
        XCTAssertFalse(String(decoding:data,as:UTF8.self).contains("Private sentinel"))
        XCTAssertEqual(try DownloadHistory.decode(data).history.records.count,1)
        XCTAssertEqual(history.nextIdentifier,2)
    }
    func testInvalidDuplicateAndFutureStateAreRejected() throws {
        var history=DownloadHistory()
        var first=DownloadRecord(phase:.complete);first.browserIdentifier=try history.allocate()
        var duplicate=DownloadRecord(phase:.complete);duplicate.browserIdentifier=first.browserIdentifier
        XCTAssertThrowsError(try history.encoded(records:[first,duplicate]))
        XCTAssertThrowsError(try history.encoded(records:[DownloadRecord(phase:.complete)]))
        let data=try history.encoded(records:[first])
        var json=try XCTUnwrap(JSONSerialization.jsonObject(with:data) as? [String:Any])
        json["nextIdentifier"]=1
        XCTAssertThrowsError(try DownloadHistory.decode(JSONSerialization.data(withJSONObject:json)))
        json["nextIdentifier"]=2;json["version"]=99
        XCTAssertThrowsError(try DownloadHistory.decode(JSONSerialization.data(withJSONObject:json)))
    }
    func testJavaScriptSafeIntegerLimitDoesNotWrap() throws {
        let json="{\"version\":1,\"nextIdentifier\":9007199254740991,\"records\":[]}"
        var history=try DownloadHistory.decode(Data(json.utf8)).history
        XCTAssertEqual(try history.allocate(),DownloadHistory.maximumIdentifier)
        XCTAssertThrowsError(try history.allocate())
        let restored=try DownloadHistory.decode(history.encoded(records:[])).history
        XCTAssertEqual(restored.nextIdentifier,DownloadHistory.maximumIdentifier+1)
    }
    func testOversizedInputAndDuplicateLegacyUUIDAreRejected() throws {
        XCTAssertThrowsError(try DownloadHistory.decode(Data(repeating:32,count:32*1024*1024+1)))
        let record=DownloadRecord(phase:.complete)
        XCTAssertThrowsError(try DownloadHistory.decode(JSONEncoder().encode([record,record])))
    }
}
