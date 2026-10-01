import XCTest
@testable import SereinCore

final class TabSelectionTests:XCTestCase {
    func testRangeUsesAnchorAndVisibleOrderInBothDirections() {
        let a=UUID(),b=UUID(),c=UUID(),d=UUID();var selection=TabSelection()
        selection.selectOnly(b);selection.range(to:d,in:[a,b,c,d])
        XCTAssertEqual(selection.ids,Set([b,c,d]))
        selection.range(to:a,in:[a,b,c,d]);XCTAssertEqual(selection.ids,Set([a,b]))
        XCTAssertEqual(selection.anchor,b)
    }
    func testToggleAndAdditiveRangePreserveOtherSelections() {
        let a=UUID(),b=UUID(),c=UUID();var selection=TabSelection()
        selection.selectOnly(a);selection.toggle(c);selection.range(to:b,in:[a,b,c],additive:true)
        XCTAssertEqual(selection.ids,Set([a,b,c]))
        selection.set(a,selected:false);XCTAssertEqual(selection.ids,Set([b,c]))
    }
    func testClosedAnchorAndHiddenEndpointCannotSelectUnrelatedTabs() {
        let a=UUID(),b=UUID(),hidden=UUID();var selection=TabSelection()
        selection.selectOnly(a);selection.retain(Set([b]))
        XCTAssertNil(selection.anchor);XCTAssertTrue(selection.ids.isEmpty)
        selection.range(to:hidden,in:[b]);XCTAssertTrue(selection.ids.isEmpty)
        selection.range(to:b,in:[b]);XCTAssertEqual(selection.ids,Set([b]))
    }
}
