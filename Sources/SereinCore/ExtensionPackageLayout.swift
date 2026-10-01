import Foundation

/// Recognizes the resource layout; this does not validate a publisher signature.
public struct ExtensionPackageLayout:Equatable {
    public let root:URL
    public let resources:URL
    public var isSafariBundle:Bool {root != resources}
    public static func inspect(_ root:URL) throws -> Self {
        let info=root.appendingPathComponent("Contents/Info.plist")
        guard FileManager.default.fileExists(atPath:info.path) else {
            if root.pathExtension.lowercased()=="appex" {throw ExtensionValidationError.invalid("The Safari extension bundle is missing Contents/Info.plist.")}
            return .init(root:root,resources:root)
        }
        let size=try info.resourceValues(forKeys:[.fileSizeKey]).fileSize ?? 0
        guard size>0,size<=1024*1024 else{throw ExtensionValidationError.invalid("The extension bundle metadata exceeds the size limit.")}
        let value=try PropertyListSerialization.propertyList(from:Data(contentsOf:info),format:nil) as? [String:Any]
        let point=(value?["NSExtension"] as? [String:Any])?["NSExtensionPointIdentifier"] as? String
        guard point=="com.apple.Safari.web-extension" else {
            throw ExtensionValidationError.invalid("Select a Safari Web Extension .appex bundle. Native Safari App Extensions and enclosing .app packages are not supported.")
        }
        guard value?["CFBundlePackageType"] as? String=="XPC!",let identifier=value?["CFBundleIdentifier"] as? String,!identifier.isEmpty else {
            throw ExtensionValidationError.invalid("The Safari Web Extension bundle metadata is incomplete.")
        }
        let resources=root.appendingPathComponent("Contents/Resources")
        guard FileManager.default.fileExists(atPath:resources.appendingPathComponent("manifest.json").path) else {
            throw ExtensionValidationError.invalid("The Safari Web Extension bundle has no manifest.json in Contents/Resources.")
        }
        return .init(root:root,resources:resources)
    }
}
