import Foundation
import CryptoKit

/// Original package declarations, not permission grants or an API support claim.
/// Kept outside extension resources so package files cannot supply the ledger.
public struct ExtensionCapabilityLedger:Codable,Equatable,Sendable {
    public let version:Int
    public let originalManifest:Data
    public let originalSHA256:String
    public let installedSHA256:String
    public let requiredPermissions:[String]
    public let requiredHosts:[String]
    public let optionalPermissions:[String]
    public let optionalHosts:[String]
    public var manifestWasNormalized:Bool {originalSHA256 != installedSHA256}

    public init(original:Data,installed:Data) throws {
        let originalDeclarations=try Self.declarations(original)
        let installedDeclarations=try Self.declarations(installed)
        guard originalDeclarations==installedDeclarations else {
            throw ExtensionValidationError.invalid("Package preparation changed capability declarations.")
        }
        version=1;originalManifest=original
        originalSHA256=Self.hash(original);installedSHA256=Self.hash(installed)
        requiredPermissions=originalDeclarations[0];requiredHosts=originalDeclarations[1]
        optionalPermissions=originalDeclarations[2];optionalHosts=originalDeclarations[3]
    }
    public func validate(installed:Data) throws {
        guard version==1,Self.hash(originalManifest)==originalSHA256,Self.hash(installed)==installedSHA256 else {
            throw ExtensionValidationError.invalid("The saved package manifest provenance does not match the installed manifest.")
        }
        let reconstructed=try Self(original:originalManifest,installed:installed)
        guard self==reconstructed else {throw ExtensionValidationError.invalid("The saved package capability ledger is inconsistent.")}
    }
    private static func hash(_ data:Data)->String {SHA256.hash(data:data).map{String(format:"%02x",$0)}.joined()}
    private static func declarations(_ data:Data) throws -> [[String]] {
        _=try ExtensionManifest(data:data)
        guard let object=try JSONSerialization.jsonObject(with:data) as? [String:Any] else {throw ExtensionValidationError.invalid("Invalid manifest object.")}
        let required=object["permissions"] as? [String] ?? [],optional=object["optional_permissions"] as? [String] ?? []
        func isHost(_ value:String)->Bool {value=="<all_urls>" || value.contains("://")}
        func unique(_ values:[String])->[String] {Set(values).sorted()}
        return [unique(required.filter{!isHost($0)}),unique(required.filter(isHost)+(object["host_permissions"] as? [String] ?? [])),
                unique(optional.filter{!isHost($0)}),unique(optional.filter(isHost)+(object["optional_host_permissions"] as? [String] ?? []))]
    }
}
