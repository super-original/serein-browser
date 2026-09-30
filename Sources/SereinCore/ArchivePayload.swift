import Foundation
import zlib

/// Check actual decoded size and CRC before creating extension resource files.
/// A signed package can still contain a malicious archive authored by its signer.
enum ArchivePayload {
    static func validate(_ bytes: ArraySlice<UInt8>, method: Int, size: Int, checksum: UInt32, consume: ((UnsafeBufferPointer<UInt8>) throws -> Void)? = nil) throws {
        func invalid() -> ExtensionValidationError { .invalid("Archive payload checksum, size, or compression is invalid.") }
        if method == 0 {
            guard bytes.count == size else { throw invalid() }
            let actual = Array(bytes).withUnsafeBufferPointer { crc32(0, $0.baseAddress, uInt($0.count)) }
            guard UInt32(actual) == checksum else { throw invalid() }
            try Array(bytes).withUnsafeBufferPointer { try consume?($0) }
            return
        }
        var stream = z_stream()
        guard inflateInit2_(&stream, -MAX_WBITS, ZLIB_VERSION, Int32(MemoryLayout<z_stream>.size)) == Z_OK else { throw invalid() }
        defer { inflateEnd(&stream) }
        var input = Array(bytes), output = [UInt8](repeating: 0, count: 32 * 1024)
        try input.withUnsafeMutableBufferPointer { source in
            stream.next_in = source.baseAddress; stream.avail_in = uInt(source.count)
            var decoded = 0, checksumValue: uLong = 0
            while true {
                let before = stream.avail_in
                let (status, produced): (Int32, Int) = try output.withUnsafeMutableBufferPointer { destination in
                    stream.next_out = destination.baseAddress; stream.avail_out = uInt(destination.count)
                    let result = inflate(&stream, Z_NO_FLUSH)
                    let count = destination.count - Int(stream.avail_out)
                    guard decoded + count <= size else { throw invalid() }
                    checksumValue = crc32(checksumValue, destination.baseAddress, uInt(count))
                    try consume?(UnsafeBufferPointer(start: destination.baseAddress, count: count))
                    return (result, count)
                }
                decoded += produced
                guard decoded <= size else { throw invalid() }
                if status == Z_STREAM_END {
                    guard stream.avail_in == 0, decoded == size, UInt32(checksumValue) == checksum else { throw invalid() }
                    return
                }
                guard status == Z_OK, produced > 0 || stream.avail_in < before else { throw invalid() }
            }
        }
    }
}
