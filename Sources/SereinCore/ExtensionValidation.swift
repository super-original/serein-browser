import Foundation
import Darwin

public enum ExtensionValidationError: LocalizedError {
    case invalid(String)
    public var errorDescription: String? {if case .invalid(let message)=self{return message};return nil}
}
public struct ExtensionManifest: Sendable {
    public let name: String
    public let version: String
    public let manifestVersion: Int
    public let permissions: [String]
    public let hosts: [String]
    public let declaredAPIPermissions:Set<String>
    public init(data: Data) throws {
        guard data.count<2_000_000,let manifest=try JSONSerialization.jsonObject(with:data) as? [String:Any],
              let name=manifest["name"] as? String,!name.isEmpty,let version=manifest["version"] as? String,!version.isEmpty,
              let mv=manifest["manifest_version"] as? Int,[2,3].contains(mv) else {throw ExtensionValidationError.invalid("A valid Manifest V2 or V3 manifest.json is required.")}
        self.name=name;self.version=version;manifestVersion=mv
        for field in ["permissions", "host_permissions", "optional_permissions", "optional_host_permissions"] {
            if let value = manifest[field], !(value is [String]) {
                throw ExtensionValidationError.invalid("Manifest \(field) must be an array of strings.")
            }
        }
        permissions=manifest["permissions"] as? [String] ?? []
        hosts=manifest["host_permissions"] as? [String] ?? []
        declaredAPIPermissions=Set((permissions+(manifest["optional_permissions"] as? [String] ?? [])).filter{!$0.contains("://") && $0 != "<all_urls>"})
        if manifest["externally_connectable"] != nil {throw ExtensionValidationError.invalid("External messaging semantics are not verified. Installation is blocked for this manifest.")}
        if manifest["devtools_page"] != nil {throw ExtensionValidationError.invalid("Developer-tools extensions are not hosted yet.")}
    }
    public func validateNativeMessagingIdentity(_ identity:SignedExtensionIdentity?) throws {
        if permissions.contains("nativeMessaging"),identity?.format != "CRX3" {
            throw ExtensionValidationError.invalid("Native messaging currently requires a verified CRX3 package and separate native-host registration. Unsigned and Firefox native-host identity verification is not implemented.")
        }
    }
    /// WebKit can omit unknown required permissions without returning a manifest
    /// error. Never present a reduced capability list as a successful install.
    public func validateRequiredPermissions(recognized: Set<String>) throws {
        let required = Set(permissions.filter { !$0.contains("://") && $0 != "<all_urls>" })
        let missing = required.subtracting(recognized).sorted()
        guard missing.isEmpty else {
            throw ExtensionValidationError.invalid("This system WebKit does not recognize required permissions: " + missing.joined(separator: ", ") + ". The extension cannot be installed with its requested capabilities.")
        }
    }
    public static func validateResourcePath(_ path: String) throws {
        guard !path.isEmpty,!path.hasPrefix("/"),!path.contains("\\"),!path.contains("\0"),!path.contains(":"),!path.split(separator:"/",omittingEmptySubsequences:false).contains("..") else {throw ExtensionValidationError.invalid("Unsafe extension resource path: \(path)")}
    }
}
/// Validate central/local names and payloads, then extract only those validated entries.
/// ZIP64, encrypted entries, Unix links, unsupported methods, and bombs fail closed.
public enum ExtensionArchive {
    private struct Entry {
        let name: String
        let method: Int
        let size: Int
        let checksum: UInt32
        let payload: Range<Int>
    }
    public static func validate(_ data: Data) throws { _ = try checkedEntries(Array(data)) }
    /// Restore file bytes only. ZIP filesystem attributes, alternate-name extras,
    /// ownership, resource forks and symlinks never reach another extractor.
    public static func extract(_ data: Data, to destination: URL) throws {
        let bytes = Array(data)
        let entries = try checkedEntries(bytes)
        let manager = FileManager.default
        guard mkdir(destination.path, 0o700) == 0 else { throw ExtensionValidationError.invalid("Extension destination must be a new private directory.") }
        do {
            for entry in entries {
                let target = destination.appendingPathComponent(entry.name)
                if entry.name.hasSuffix("/") {
                    try manager.createDirectory(at: target, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
                    continue
                }
                try manager.createDirectory(at: target.deletingLastPathComponent(), withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
                let descriptor = open(target.path, O_WRONLY | O_CREAT | O_EXCL | O_NOFOLLOW, 0o600)
                guard descriptor >= 0 else { throw ExtensionValidationError.invalid("Could not create an exclusive extension resource file.") }
                let file = FileHandle(fileDescriptor: descriptor, closeOnDealloc: true)
                do {
                    try ArchivePayload.validate(bytes[entry.payload], method: entry.method, size: entry.size, checksum: entry.checksum) {
                        try writePayload($0,to:descriptor)
                    }
                    try file.close()
                } catch { try? file.close(); throw error }
            }
        } catch { try? manager.removeItem(at: destination); throw error }
    }
    private static func writePayload(_ buffer:UnsafeBufferPointer<UInt8>,to descriptor:Int32) throws {
        guard !buffer.isEmpty else{return}
        guard let address=buffer.baseAddress else{throw NSError(domain:NSPOSIXErrorDomain,code:Int(EFAULT))}
        var offset=0
        while offset<buffer.count {
            let written=Darwin.write(descriptor,address.advanced(by:offset),buffer.count-offset)
            if written<0 {
                if errno==EINTR {continue}
                throw NSError(domain:NSPOSIXErrorDomain,code:Int(errno))
            }
            guard written>0 else{throw NSError(domain:NSPOSIXErrorDomain,code:Int(EIO))}
            offset+=written
        }
    }
    private static func checkedEntries(_ b: [UInt8]) throws -> [Entry] {
        var entries: [Entry] = []
        func u16(_ i: Int) throws -> Int {guard i>=0,i+2<=b.count else{throw ExtensionValidationError.invalid("Truncated archive.")};return Int(b[i]) | Int(b[i+1])<<8}
        func u32(_ i: Int) throws -> Int {try u16(i) | u16(i+2)<<16}
        guard b.count>=22,b.count<=64*1024*1024 else{throw ExtensionValidationError.invalid("Archive must be smaller than 64 MiB.")}
        var end: Int?
        for i in stride(from:b.count-22,through:max(0,b.count-65557),by:-1) {
            if try u32(i)==0x06054b50, i+22+(try u16(i+20))==b.count {end=i;break}
        }
        guard let e=end,try u16(e+4)==0,try u16(e+6)==0 else{throw ExtensionValidationError.invalid("Multi-volume or malformed archive.")}
        let count=try u16(e+10);var cursor=try u32(e+16);var total=0;var names=Set<String>()
        guard count>0,count<10_000,try u16(e+8)==count,cursor+(try u32(e+12))==e else{throw ExtensionValidationError.invalid("ZIP64 or malformed archive directory.")}
        for _ in 0..<count {
            guard try u32(cursor)==0x02014b50 else{throw ExtensionValidationError.invalid("Invalid archive directory.")}
            let flags=try u16(cursor+8),method=try u16(cursor+10),packed=try u32(cursor+20),unpacked=try u32(cursor+24)
            let n=try u16(cursor+28),extra=try u16(cursor+30),comment=try u16(cursor+32),mode=(try u32(cursor+38))>>16,local=try u32(cursor+42)
            guard flags & 1==0,[0,8].contains(method),[0,0o100000,0o040000].contains(mode & 0o170000),cursor+46+n+extra+comment<=e,
                  let name=String(bytes:b[(cursor+46)..<(cursor+46+n)],encoding:.utf8) else{throw ExtensionValidationError.invalid("Unsupported or unsafe archive entry.")}
            try ExtensionManifest.validateResourcePath(name)
            let components = name.split(separator: "/", omittingEmptySubsequences: false)
            let pathComponents = name.hasSuffix("/") ? Array(components.dropLast()) : components
            guard pathComponents.allSatisfy({ !$0.isEmpty && $0 != "." }) else { throw ExtensionValidationError.invalid("Ambiguous archive resource path.") }
            let canonicalName = pathComponents.joined(separator: "/").precomposedStringWithCanonicalMapping.lowercased()
            guard names.insert(canonicalName).inserted else{throw ExtensionValidationError.invalid("Duplicate resource path.")}
            total+=unpacked
            guard total<=128*1024*1024,unpacked<=max(1,packed)*1000 else{throw ExtensionValidationError.invalid("Extension expands beyond the permitted size.")}
            guard try u32(local)==0x04034b50 else{throw ExtensionValidationError.invalid("Invalid local header.")}
            let ln=try u16(local+26),le=try u16(local+28)
            guard local+30+ln+le+packed<=e,ln==n,String(bytes:b[(local+30)..<(local+30+ln)],encoding:.utf8)==name,
                  try u16(local+6)==flags,try u16(local+8)==method else{throw ExtensionValidationError.invalid("Inconsistent archive headers.")}
            let checksum = try u32(cursor+16)
            if flags & 8 == 0 {
                guard try u32(local+14) == checksum, try u32(local+18) == packed, try u32(local+22) == unpacked else {
                    throw ExtensionValidationError.invalid("Inconsistent local payload metadata.")
                }
            }
            let payload = local+30+ln+le
            try ArchivePayload.validate(b[payload..<(payload+packed)], method: method, size: unpacked, checksum: UInt32(checksum))
            entries.append(Entry(name: name, method: method, size: unpacked, checksum: UInt32(checksum), payload: payload..<(payload+packed)))
            cursor+=46+n+extra+comment
        }
        guard cursor==e else{throw ExtensionValidationError.invalid("Unexpected archive directory content.")}
        return entries
    }
}
