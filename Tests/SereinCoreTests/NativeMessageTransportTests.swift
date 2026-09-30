import XCTest
@testable import SereinCore

@MainActor final class NativeMessageTransportTests:XCTestCase {
    func testCancelBeforeStartClosesStreamWithoutLaunching() async throws {
        let transport=NativeMessageTransport(executable:URL(fileURLWithPath:"/nonexistent-serein-test-host"),arguments:[])
        transport.cancel();transport.start()
        var iterator=transport.messages.makeAsyncIterator()
        let message=try await iterator.next();XCTAssertNil(message)
    }
    func testActualProcessEchoesOrderedFrames() async throws {
        let transport=NativeMessageTransport(executable:URL(fileURLWithPath:"/bin/cat"),arguments:[],maximumLifetime:5)
        defer{transport.cancel()}
        let first=try NativeMessageFraming.encode(["value":"雪"]),second=try NativeMessageFraming.encode([1,2,3])
        try transport.send(first);try transport.send(second);transport.start()
        var messages=transport.messages.makeAsyncIterator()
        let a=try await messages.next(),b=try await messages.next()
        XCTAssertEqual(a,Data(first.dropFirst(4)));XCTAssertEqual(b,Data(second.dropFirst(4)))
        transport.cancel()
        let end=try await messages.next();XCTAssertNil(end)
        XCTAssertThrowsError(try transport.send(first))
    }
    func testHostInitiatedMessageAndEOF() async throws {
        let transport=NativeMessageTransport(executable:URL(fileURLWithPath:"/usr/bin/printf"),arguments:["\\004\\000\\000\\000null"],maximumLifetime:5)
        transport.start();defer{transport.cancel()}
        var results:[Data]=[]
        for try await message in transport.messages {results.append(message)}
        XCTAssertEqual(results,[Data("null".utf8)])
    }
    func testTruncatedHostOutputFails() async {
        let transport=NativeMessageTransport(executable:URL(fileURLWithPath:"/usr/bin/printf"),arguments:["\\004\\000"],maximumLifetime:5)
        transport.start();defer{transport.cancel()}
        do {for try await _ in transport.messages {};XCTFail("Truncated frame was accepted")}
        catch {XCTAssertTrue(error is NativeMessageFramingError)}
    }
    func testSilentHostDeadlineDoesNotHang() async {
        let transport=NativeMessageTransport(executable:URL(fileURLWithPath:"/bin/sleep"),arguments:["5"],maximumLifetime:0.2)
        transport.start();defer{transport.cancel()}
        do {for try await _ in transport.messages {};XCTFail("Expected deadline")}
        catch {guard case NativeMessageTransportError.deadline=error else{return XCTFail("Unexpected error: \(error)")}}
    }
    func testFailedLaunchReportsError() async {
        let transport=NativeMessageTransport(executable:URL(fileURLWithPath:"/nonexistent-serein-test-host"),arguments:[],maximumLifetime:1)
        transport.start();defer{transport.cancel()}
        do {for try await _ in transport.messages {};XCTFail("Missing host was accepted")}
        catch {}
    }
}
