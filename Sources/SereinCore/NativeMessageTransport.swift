import Foundation
import Darwin

public enum NativeMessageTransportError:LocalizedError {
    case unavailable,backpressure,io(Int32),hostExit(Int32),deadline
    public var errorDescription:String? {
        switch self {
        case .unavailable:return "The native messaging connection is closed."
        case .backpressure:return "The native messaging queue is full."
        case .io(let code):return "Native messaging pipe error \(code)."
        case .hostExit(let status):return "The native messaging host exited with status \(status)."
        case .deadline:return "The native messaging host did not finish before the deadline."
        }
    }
}

/// Transport only: callers must authorize a registered executable and extension
/// identity before constructing this object. No production extension delegate
/// currently calls it. Mutable queue state is protected by lock; process/pipe
/// objects and decoder are confined to one worker thread.
public final class NativeMessageTransport:@unchecked Sendable {
    public let messages:AsyncThrowingStream<Data,Error>
    private let continuation:AsyncThrowingStream<Data,Error>.Continuation
    private let executable:URL
    private let arguments:[String]
    private let lifetime:TimeInterval?
    private let lock=NSLock()
    private var cancelled=false
    private var started=false
    private var queue:[Data]=[]
    private var queuedBytes=0
    public init(executable:URL,arguments:[String],maximumLifetime:TimeInterval?=30) {
        self.executable=executable;self.arguments=arguments;self.lifetime=maximumLifetime
        let channel=AsyncThrowingStream<Data,Error>.makeStream(bufferingPolicy:.bufferingOldest(8))
        messages=channel.stream;continuation=channel.continuation
        continuation.onTermination={ [weak self] _ in self?.cancel() }
    }
    public func start() {
        lock.lock()
        guard !started,!cancelled else{lock.unlock();return}
        started=true;lock.unlock()
        DispatchQueue.global(qos:.utility).async{self.run()}
    }
    public func send(_ frame:Data) throws {
        guard frame.count<=NativeMessageFraming.maximumChromeRequest+4 else{throw NativeMessageFramingError.invalidLength}
        lock.lock();defer{lock.unlock()}
        guard !cancelled else{throw NativeMessageTransportError.unavailable}
        guard queue.count<32,queuedBytes+frame.count<=NativeMessageFraming.maximumChromeRequest+4 else{throw NativeMessageTransportError.backpressure}
        queue.append(frame);queuedBytes += frame.count
    }
    public func cancel(){
        lock.lock();let finish = !started && !cancelled
        cancelled=true;queue=[];queuedBytes=0;lock.unlock()
        if finish{continuation.finish()}
    }
    private var isCancelled:Bool {lock.lock();defer{lock.unlock()};return cancelled}
    private func nextFrame()->Data? {
        lock.lock();defer{lock.unlock()}
        guard !queue.isEmpty else{return nil}
        return queue.removeFirst()
    }
    private func consumed(_ count:Int){lock.lock();queuedBytes=max(0,queuedBytes-count);lock.unlock()}
    private func run() {
        let process=Process(),input=Pipe(),output=Pipe()
        process.executableURL=executable;process.arguments=arguments
        process.currentDirectoryURL=executable.deletingLastPathComponent()
        process.standardInput=input;process.standardOutput=output
        // Host diagnostics may contain private messages. Do not copy them into
        // browser logs, and never mix stderr into the framed stdout stream.
        process.standardError=FileHandle.nullDevice
        var launched=false
        var terminalError:Error?
        defer {
            try? input.fileHandleForWriting.close();try? output.fileHandleForReading.close()
            if process.isRunning {
                process.terminate()
                for _ in 0..<20 {if !process.isRunning{break};Thread.sleep(forTimeInterval:0.01)}
                if process.isRunning {kill(process.processIdentifier,SIGKILL)}
            }
            if launched {process.waitUntilExit()}
            cancel();continuation.finish(throwing:terminalError)
        }
        do {
            guard executable.isFileURL,executable.path.hasPrefix("/"),lifetime.map({$0.isFinite && $0>0}) ?? true else{throw NativeMessageTransportError.unavailable}
            try process.run();launched=true
            try input.fileHandleForReading.close();try output.fileHandleForWriting.close()
            let reader=output.fileHandleForReading.fileDescriptor,writer=input.fileHandleForWriting.fileDescriptor
            guard fcntl(reader,F_SETFL,fcntl(reader,F_GETFL) | O_NONBLOCK)>=0,
                  fcntl(writer,F_SETFL,fcntl(writer,F_GETFL) | O_NONBLOCK)>=0,
                  fcntl(writer,F_SETNOSIGPIPE,1)>=0 else{throw NativeMessageTransportError.io(errno)}
            var decoder=NativeMessageDecoder(),pending=Data(),offset=0
            let deadline=lifetime.map{ProcessInfo.processInfo.systemUptime+$0}
            var buffer=[UInt8](repeating:0,count:16*1024)
            while !isCancelled {
                if let deadline,ProcessInfo.processInfo.systemUptime>=deadline {throw NativeMessageTransportError.deadline}
                if pending.isEmpty,let frame=nextFrame(){pending=frame;offset=0}
                var descriptors=[pollfd(fd:reader,events:Int16(POLLIN),revents:0),pollfd(fd:writer,events:pending.isEmpty ? 0 : Int16(POLLOUT),revents:0)]
                let ready=poll(&descriptors,2,25)
                if ready<0 {if errno==EINTR{continue};throw NativeMessageTransportError.io(errno)}
                if descriptors[0].revents & Int16(POLLIN | POLLHUP | POLLERR) != 0 {
                    let count=read(reader,&buffer,16*1024)
                    if count>0 {
                        for message in try decoder.append(Data(buffer.prefix(count))) {
                            if case .dropped = continuation.yield(message){throw NativeMessageTransportError.backpressure}
                        }
                    } else if count==0 {
                        try decoder.finish()
                        // EOF is a protocol close; an already observed abnormal
                        // process exit is still returned as an error.
                        if !process.isRunning,process.terminationStatus != 0 {throw NativeMessageTransportError.hostExit(process.terminationStatus)}
                        return
                    } else if errno != EAGAIN && errno != EINTR {throw NativeMessageTransportError.io(errno)}
                }
                if !pending.isEmpty,descriptors[1].revents & Int16(POLLOUT | POLLHUP | POLLERR) != 0 {
                    let count=pending.withUnsafeBytes{bytes in write(writer,bytes.baseAddress!.advanced(by:offset),pending.count-offset)}
                    if count>0 {offset += count;if offset==pending.count{consumed(pending.count);pending=Data();offset=0}}
                    else if count<0,errno != EAGAIN && errno != EINTR {throw NativeMessageTransportError.io(errno)}
                }
            }
        } catch {terminalError=error}
    }
}
