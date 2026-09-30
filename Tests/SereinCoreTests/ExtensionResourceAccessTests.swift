import XCTest
@testable import SereinCore

final class ExtensionResourceAccessTests:XCTestCase {
    func testPrivateResourcesAndTraversalAreDenied() {
        let manifest:[String:Any] = ["manifest_version":2,"web_accessible_resources":["public/*"]]
        for path in ["options.html","public/../options.html","public\\options.html"] {
            XCTAssertFalse(ExtensionResourceAccess.allows(path:path,manifest:manifest,sourceExtensionID:nil){_ in true})
        }
    }
    func testMV2ResourceGlobsAreAnchoredAndRecursive() {
        let manifest:[String:Any] = ["manifest_version":2,"web_accessible_resources":["/images/*","*.png"]]
        for path in ["/images/nested/icon.svg","nested/icon.png"] {XCTAssertTrue(ExtensionResourceAccess.allows(path:path,manifest:manifest,sourceExtensionID:nil){_ in false})}
        XCTAssertFalse(ExtensionResourceAccess.allows(path:"icon.png\n",manifest:manifest,sourceExtensionID:nil){_ in true})
        XCTAssertFalse(ExtensionResourceAccess.allows(path:"icon.png.html",manifest:manifest,sourceExtensionID:nil){_ in true})
    }
    func testMV3ScopesResourcesAndInitiatorsTogether() {
        let manifest:[String:Any] = ["manifest_version":3,"web_accessible_resources":[
            ["resources":["public.html"],"matches":["https://allowed.test/*"]],
            ["resources":["shared.html"],"extension_ids":["trusted-id"]]]]
        XCTAssertTrue(ExtensionResourceAccess.allows(path:"public.html",manifest:manifest,sourceExtensionID:nil){$0=="https://allowed.test/*"})
        XCTAssertFalse(ExtensionResourceAccess.allows(path:"public.html",manifest:manifest,sourceExtensionID:nil){_ in false})
        XCTAssertFalse(ExtensionResourceAccess.allows(path:"shared.html",manifest:manifest,sourceExtensionID:nil){_ in true})
        XCTAssertTrue(ExtensionResourceAccess.allows(path:"shared.html",manifest:manifest,sourceExtensionID:"trusted-id"){_ in false})
        XCTAssertFalse(ExtensionResourceAccess.allows(path:"shared.html",manifest:manifest,sourceExtensionID:"other-id"){_ in true})
    }
    func testRepeatedWildcardsAndLiteralRegexCharacters() {
        let manifest:[String:Any] = ["manifest_version":2,"web_accessible_resources":[String(repeating:"*a",count:80)+"b", "folder/(literal).html", "*tail"]]
        XCTAssertFalse(ExtensionResourceAccess.allows(path:String(repeating:"a",count:2000)+"c",manifest:manifest,sourceExtensionID:nil){_ in true})
        XCTAssertTrue(ExtensionResourceAccess.allows(path:"folder/(literal).html",manifest:manifest,sourceExtensionID:nil){_ in false})
        XCTAssertFalse(ExtensionResourceAccess.allows(path:"folder/literal.html",manifest:manifest,sourceExtensionID:nil){_ in true})
        XCTAssertTrue(ExtensionResourceAccess.allows(path:"*nested/tail",manifest:manifest,sourceExtensionID:nil){_ in false})
    }
    func testStaticOriginsDoNotSatisfyDynamicResourceRules() {
        let manifest:[String:Any] = ["manifest_version":3,"web_accessible_resources":[["resources":["*"],"matches":["<all_urls>"],"use_dynamic_url":true]]]
        XCTAssertFalse(ExtensionResourceAccess.allows(path:"public.html",manifest:manifest,sourceExtensionID:nil){_ in true})
    }
}
