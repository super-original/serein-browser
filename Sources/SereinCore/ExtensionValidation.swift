import Foundation

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
    public init(data: Data) throws {
        guard data.count<2_000_000,let manifest=try JSONSerialization.jsonObject(with:data) as? [String:Any],
              let name=manifest["name"] as? String,!name.isEmpty,let version=manifest["version"] as? String,!version.isEmpty,
              let mv=manifest["manifest_version"] as? Int,[2,3].contains(mv) else {throw ExtensionValidationError.invalid("A valid Manifest V2 or V3 manifest.json is required.")}
        self.name=name;self.version=version;manifestVersion=mv
        permissions=manifest["permissions"] as? [String] ?? []
        hosts=manifest["host_permissions"] as? [String] ?? []
        if permissions.contains("nativeMessaging") {throw ExtensionValidationError.invalid("Native messaging is not implemented. This extension cannot be installed with its requested capabilities.")}
        if manifest["externally_connectable"] != nil {throw ExtensionValidationError.invalid("External messaging semantics are not verified. Installation is blocked for this manifest.")}
        if manifest["devtools_page"] != nil {throw ExtensionValidationError.invalid("Developer-tools extensions are not hosted yet.")}
    }
    public static func validateResourcePath(_ path: String) throws {
        guard !path.isEmpty,!path.hasPrefix("/"),!path.contains("\\"),!path.contains("\0"),!path.contains(":"),!path.split(separator:"/",omittingEmptySubsequences:false).contains("..") else {throw ExtensionValidationError.invalid("Unsafe extension resource path: \(path)")}
    }
}
/// Validate both central and local ZIP names before passing an archive to the OS extractor.
/// ZIP64, encrypted entries, Unix links, unsupported methods, and bombs fail closed.
public enum ExtensionArchive {
    public static func validate(_ data: Data) throws {
        let b=[UInt8](data)
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
            guard flags & 1==0,[0,8].contains(method),mode & 0o170000 != 0o120000,cursor+46+n+extra+comment<=e,
                  let name=String(bytes:b[(cursor+46)..<(cursor+46+n)],encoding:.utf8) else{throw ExtensionValidationError.invalid("Unsupported or unsafe archive entry.")}
            try ExtensionManifest.validateResourcePath(name)
            guard names.insert(name.lowercased()).inserted else{throw ExtensionValidationError.invalid("Duplicate resource path.")}
            total+=unpacked
            guard total<=128*1024*1024,unpacked<=max(1,packed)*1000 else{throw ExtensionValidationError.invalid("Extension expands beyond the permitted size.")}
            guard try u32(local)==0x04034b50 else{throw ExtensionValidationError.invalid("Invalid local header.")}
            let ln=try u16(local+26),le=try u16(local+28)
            guard local+30+ln+le+packed<=e,ln==n,String(bytes:b[(local+30)..<(local+30+ln)],encoding:.utf8)==name,
                  try u16(local+6)==flags,try u16(local+8)==method else{throw ExtensionValidationError.invalid("Inconsistent archive headers.")}
            cursor+=46+n+extra+comment
        }
        guard cursor==e else{throw ExtensionValidationError.invalid("Unexpected archive directory content.")}
    }
}
