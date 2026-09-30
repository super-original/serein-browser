import CoreGraphics
import XCTest
@testable import SereinCore

final class WindowPlacementTests:XCTestCase {
    private let main=CGRect(x:0,y:40,width:1440,height:860)
    func testValidFrameAndNegativeCoordinateDisplayRemainUnchanged() {
        let left=CGRect(x:-1920,y:0,width:1920,height:1080)
        XCTAssertEqual(WindowPlacement.restored([-1800,100,1000,700],screens:[main,left]),CGRect(x:-1800,y:100,width:1000,height:700))
    }
    func testSliverIntersectionAndDisconnectedDisplayBecomeReachable() {
        XCTAssertEqual(WindowPlacement.restored([1439,899,1000,700],screens:[main]),CGRect(x:440,y:200,width:1000,height:700))
        XCTAssertEqual(WindowPlacement.restored([8000,-2000,3000,2000],screens:[main]),main)
    }
    func testLargestIntersectionWinsInsteadOfFirstScreen() {
        let right=CGRect(x:1440,y:40,width:1440,height:860)
        XCTAssertEqual(WindowPlacement.restored([1300,80,1000,700],screens:[main,right]),CGRect(x:1440,y:80,width:1000,height:700))
    }
    func testMalformedFramesAndSmallScreen() {
        let frames:[[Double]?]=[nil,[],[0,0,10,10],[Double.nan,0,800,600],[0,0,Double.infinity,600]]
        for frame in frames {
            XCTAssertNil(WindowPlacement.restored(frame,screens:[main]))
        }
        XCTAssertNil(WindowPlacement.restored([0,0,800,600],screens:[]))
        XCTAssertEqual(WindowPlacement.restored([0,0,800,600],screens:[CGRect(x:0,y:20,width:500,height:300)]),CGRect(x:0,y:-80,width:640,height:400))
    }
}
