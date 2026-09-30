import XCTest
@testable import SereinCore

final class NativeHostManifestTests:XCTestCase {
    private let identifier=String(repeating:"a",count:32)
    private func data(_ changes:[String:Any]=[:]) throws -> Data {
        var value:[String:Any]=["name":"org.serein.test_host","description":"Test host","path":"/Applications/Test App/host","type":"stdio","allowed_origins":["chrome-extension://"+identifier+"/"]]
        value.merge(changes){_,new in new};return try JSONSerialization.data(withJSONObject:value)
    }
    func testExactSignedOriginAndRoundTrip() throws {
        let manifest=try NativeHostManifest(data:data())
        let identity=SignedExtensionIdentity(format:"CRX3",extensionID:identifier,publicKeySHA256:"fixture",packageSHA256:"fixture")
        XCTAssertEqual(try manifest.origin(for:identity),"chrome-extension://"+identifier+"/")
        XCTAssertEqual(try JSONDecoder().decode(NativeHostManifest.self,from:JSONEncoder().encode(manifest)),manifest)
        let other=SignedExtensionIdentity(format:"CRX3",extensionID:String(repeating:"b",count:32),publicKeySHA256:"other",packageSHA256:"other")
        XCTAssertThrowsError(try manifest.origin(for:other))
    }
    func testMalformedNamesPathsAndOriginsRejected() throws {
        let changes:[[String:Any]]=[
            ["name":"../escape"],["name":"org..host"],["name":".host"],["name":"host."],["name":"Host"],
            ["path":"relative/host"],["path":"/host\0arg"],["type":"shell"],["allowed_origins":[]],
            ["allowed_origins":["chrome-extension://*/"]],["allowed_origins":["chrome-extension://"+identifier+"/page.html"]],
            ["allowed_origins":["chrome-extension://"+identifier+"/?query"]],["allowed_origins":["webkit-extension://"+identifier+"/"]]
        ]
        for value in changes {XCTAssertThrowsError(try NativeHostManifest(data:data(value)),"Accepted \(value)")}
    }
    func testFirefoxIDAndUnverifiedFormatDoNotAuthorizeChromeHost() throws {
        let manifest=try NativeHostManifest(data:data())
        let unsigned=SignedExtensionIdentity(format:"XPI",extensionID:identifier,publicKeySHA256:"",packageSHA256:"")
        XCTAssertThrowsError(try manifest.origin(for:unsigned))
        var value=try JSONSerialization.jsonObject(with:data()) as! [String:Any]
        value.removeValue(forKey:"allowed_origins");value["allowed_extensions"]=["test@example.invalid"]
        XCTAssertThrowsError(try NativeHostManifest(data:JSONSerialization.data(withJSONObject:value)))
    }
}
