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
/// identity before constructing this object. Mutable queue state is protected by lock; process/pipe
/// objects and decoder are confined to one worker thread.
public final class NativeMessageTransport:@unchecked Sendable {
    public let messages:AsyncThrowingStream<Data,Error>
    private let continuation:AsyncThrowingStream<Data,Error>.Continuation
    private let executable:URL
    private let arguments:[String]
    private let lifetime:TimeInterval?
    private let lock=NSLock()
    private let wake=Pipe()
    private var cancelled=false
    private var started=false
    private var queue:[Data]=[]
    private var queuedBytes=0
    private var closed=false
    private var closeWaiters:[CheckedContinuation<Void,Never>]=[]
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
        queue.append(frame);queuedBytes += frame.count;signal()
    }
    public func cancel(){
        lock.lock();let finish = !started && !cancelled,changed = !cancelled
        cancelled=true;queue=[];queuedBytes=0;lock.unlock()
        if changed{signal()}
        if finish{markClosed();continuation.finish()}
    }
    private func signal(){var byte:UInt8=1;_ = write(wake.fileHandleForWriting.fileDescriptor,&byte,1)}
    public func close() async {
        cancel()
        await withCheckedContinuation { continuation in
            lock.lock()
            if closed {lock.unlock();continuation.resume()}
            else {closeWaiters.append(continuation);lock.unlock()}
        }
    }
    private func markClosed() {
        lock.lock();closed=true;let waiters=closeWaiters;closeWaiters=[];lock.unlock()
        for waiter in waiters {waiter.resume()}
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
            cancel();markClosed();continuation.finish(throwing:terminalError)
        }
        do {
            guard executable.isFileURL,executable.path.hasPrefix("/"),lifetime.map({$0.isFinite && $0>0}) ?? true else{throw NativeMessageTransportError.unavailable}
            guard !isCancelled else{return}
            try process.run();launched=true
            try input.fileHandleForReading.close();try output.fileHandleForWriting.close()
            let reader=output.fileHandleForReading.fileDescriptor,writer=input.fileHandleForWriting.fileDescriptor
            let wakeReader=wake.fileHandleForReading.fileDescriptor,wakeWriter=wake.fileHandleForWriting.fileDescriptor
            guard fcntl(reader,F_SETFL,fcntl(reader,F_GETFL) | O_NONBLOCK)>=0,
                  fcntl(writer,F_SETFL,fcntl(writer,F_GETFL) | O_NONBLOCK)>=0,
                  fcntl(wakeReader,F_SETFL,fcntl(wakeReader,F_GETFL) | O_NONBLOCK)>=0,
                  fcntl(wakeWriter,F_SETFL,fcntl(wakeWriter,F_GETFL) | O_NONBLOCK)>=0,
                  fcntl(writer,F_SETNOSIGPIPE,1)>=0 else{throw NativeMessageTransportError.io(errno)}
            var decoder=NativeMessageDecoder(),pending=Data(),offset=0
            let deadline=lifetime.map{ProcessInfo.processInfo.systemUptime+$0}
            var buffer=[UInt8](repeating:0,count:16*1024)
            while !isCancelled {
                if let deadline,ProcessInfo.processInfo.systemUptime>=deadline {throw NativeMessageTransportError.deadline}
                if pending.isEmpty,let frame=nextFrame(){pending=frame;offset=0}
                var descriptors=[pollfd(fd:reader,events:Int16(POLLIN),revents:0),pollfd(fd:pending.isEmpty ? -1 : writer,events:Int16(POLLOUT),revents:0),pollfd(fd:wakeReader,events:Int16(POLLIN),revents:0)]
                let timeout=deadline.map{Int32(max(0,min(Double(Int32.max),($0-ProcessInfo.processInfo.systemUptime)*1000)))} ?? -1
                let ready=poll(&descriptors,3,timeout)
                if ready<0 {if errno==EINTR{continue};throw NativeMessageTransportError.io(errno)}
                if isCancelled{break}
                if descriptors.contains(where:{$0.revents & Int16(POLLNVAL) != 0}){throw NativeMessageTransportError.io(EBADF)}
                if descriptors[2].revents & Int16(POLLIN) != 0 {_ = read(wakeReader,&buffer,16*1024)}
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
