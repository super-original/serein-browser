import XCTest
@testable import SereinCore

final class ExtensionCapabilityLedgerTests:XCTestCase {
    private func manifest(_ extra:String)->Data {Data(("{\"manifest_version\":3,\"name\":\"Ledger\",\"version\":\"1.0\","+extra+"}").utf8)}
    func testOriginalOptionalAndRequiredDeclarationsSurviveNormalization() throws {
        let original=manifest("\"permissions\":[\"storage\",\"downloads\",\"storage\",\"https://required.test/*\"],\"host_permissions\":[\"https://other.test/*\"],\"optional_permissions\":[\"history\",\"https://optional.test/*\"],\"optional_host_permissions\":[\"<all_urls>\"],\"commands\":{\"_execute_action\":{}}")
        let installed=try ExtensionCommandNormalization.normalize(original)
        let ledger=try ExtensionCapabilityLedger(original:original,installed:installed)
        XCTAssertTrue(ledger.manifestWasNormalized)
        XCTAssertEqual(ledger.originalManifest,original)
        XCTAssertEqual(ledger.requiredPermissions,["downloads","storage"])
        XCTAssertEqual(ledger.requiredHosts,["https://other.test/*","https://required.test/*"])
        XCTAssertEqual(ledger.optionalPermissions,["history"])
        XCTAssertEqual(ledger.optionalHosts,["<all_urls>","https://optional.test/*"])
        let restored=try JSONDecoder().decode(ExtensionCapabilityLedger.self,from:JSONEncoder().encode(ledger))
        try restored.validate(installed:installed)
        XCTAssertEqual(restored,ledger)
    }
    func testPreparationCannotSilentlyStripOrPromoteCapabilities() throws {
        let original=manifest("\"permissions\":[\"downloads\"],\"optional_permissions\":[\"history\"]")
        for extra in ["\"permissions\":[],\"optional_permissions\":[\"history\"]","\"permissions\":[\"downloads\",\"history\"]","\"permissions\":[\"downloads\"],\"optional_permissions\":[\"history\"],\"host_permissions\":[\"<all_urls>\"]"] {
            XCTAssertThrowsError(try ExtensionCapabilityLedger(original:original,installed:manifest(extra)))
        }
    }
    func testLedgerRejectsChangedManifestAndTamperedSerializedDeclarations() throws {
        let original=manifest("\"permissions\":[\"storage\"]")
        let ledger=try ExtensionCapabilityLedger(original:original,installed:original)
        XCTAssertFalse(ledger.manifestWasNormalized)
        XCTAssertThrowsError(try ledger.validate(installed:original+Data(" ".utf8)))
        var object=try XCTUnwrap(JSONSerialization.jsonObject(with:JSONEncoder().encode(ledger)) as? [String:Any])
        for (field,value) in [("requiredPermissions",["downloads"] as Any),("version",2 as Any),("originalSHA256","bad" as Any)] {
            var changed=object;changed[field]=value
            let restored=try JSONDecoder().decode(ExtensionCapabilityLedger.self,from:JSONSerialization.data(withJSONObject:changed))
            XCTAssertThrowsError(try restored.validate(installed:original))
        }
        object["originalManifest"]=Data("{}".utf8).base64EncodedString()
        let changed=try JSONDecoder().decode(ExtensionCapabilityLedger.self,from:JSONSerialization.data(withJSONObject:object))
        XCTAssertThrowsError(try changed.validate(installed:original))
    }
}
