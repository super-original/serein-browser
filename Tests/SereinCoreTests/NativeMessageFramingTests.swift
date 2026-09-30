import XCTest
@testable import SereinCore

final class NativeMessageFramingTests:XCTestCase {
    func testEveryByteFragmentedAndCoalescedFramesPreserveOrdering() throws {
        let values:[Any]=[["text":"雪","values":[true,NSNull(),42]],"hello",NSNull(),[1,2,3]]
        let frames=try values.map{try NativeMessageFraming.encode($0)}
        let joined=frames.reduce(into:Data()){$0.append($1)}
        var fragmented=NativeMessageDecoder(),coalesced=NativeMessageDecoder()
        var decoded:[Data]=[]
        for byte in joined {decoded += try fragmented.append(Data([byte]))}
        XCTAssertEqual(decoded,try coalesced.append(joined))
        XCTAssertEqual(decoded,frames.map{Data($0.dropFirst(4))})
        try fragmented.finish();try coalesced.finish()
    }
    func testNativeLittleEndianLengthCountsUTF8Bytes() throws {
        let data=try NativeMessageFraming.encode("雪")
        XCTAssertEqual(Array(data.prefix(4)),[5,0,0,0])
        XCTAssertEqual(String(data:Data(data.dropFirst(4)),encoding:.utf8),"\"雪\"")
    }
    func testMaximumHostFramesCanBeCoalescedWithoutFalseOverflow() throws {
        let frame=try NativeMessageFraming.encode(String(repeating:"a",count:NativeMessageFraming.maximumHostMessage-2))
        XCTAssertEqual(frame.count,NativeMessageFraming.maximumHostMessage+4)
        var decoder=NativeMessageDecoder()
        let messages=try decoder.append(frame+frame)
        XCTAssertEqual(messages.count,2)
        XCTAssertEqual(messages[0].count,NativeMessageFraming.maximumHostMessage)
        try decoder.finish()
    }
    func testOversizedLengthRejectedBeforeBodyAndDecoderStaysFailed() throws {
        var decoder=NativeMessageDecoder()
        XCTAssertThrowsError(try decoder.append(Data([1,0,16,0])))
        XCTAssertThrowsError(try decoder.append(NativeMessageFraming.encode("valid")))
        XCTAssertThrowsError(try decoder.finish())
        var zero=NativeMessageDecoder();XCTAssertThrowsError(try zero.append(Data([0,0,0,0])))
    }
    func testPartialHeaderAndBodyFailAtEOF() throws {
        var header=NativeMessageDecoder(),body=NativeMessageDecoder()
        _=try header.append(Data([2,0]));XCTAssertThrowsError(try header.finish())
        _=try body.append(Data([2,0,0,0,123]));XCTAssertThrowsError(try body.finish())
    }
    func testInvalidJSONAndUTF8Rejected() throws {
        let bytes:[UInt8]=[0xff,123]
        for byte in bytes {
            var decoder=NativeMessageDecoder()
            XCTAssertThrowsError(try decoder.append(Data([1,0,0,0,byte])))
        }
        XCTAssertThrowsError(try NativeMessageFraming.encode(Double.nan))
        XCTAssertThrowsError(try NativeMessageFraming.encode("message",maximumBytes:2))
    }
}
