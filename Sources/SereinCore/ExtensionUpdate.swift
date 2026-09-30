import Foundation

/// Chrome manifest versions use one to four bounded ASCII integers; omitted parts are zero.
public struct ExtensionVersion: Comparable, Sendable {
    private let components: [Int]
    public init(_ text: String) throws {
        let fields = text.split(separator: ".", omittingEmptySubsequences: false)
        guard (1...4).contains(fields.count) else { throw ExtensionValidationError.invalid("A signed update needs a Chrome-format numeric version.") }
        var values: [Int] = []
        for field in fields {
            guard !field.isEmpty, field.utf8.allSatisfy({ (48...57).contains($0) }),
                  field.count == 1 || field.first != "0", let value = Int(field), value <= 65535 else {
                throw ExtensionValidationError.invalid("Invalid signed extension version: \(text)")
            }
            values.append(value)
        }
        guard values.contains(where: { $0 != 0 }) else { throw ExtensionValidationError.invalid("An extension version cannot be all zero.") }
        components = values + Array(repeating: 0, count: 4-values.count)
    }
    public static func < (lhs: Self, rhs: Self) -> Bool { lhs.components.lexicographicallyPrecedes(rhs.components) }
}
public enum SignedExtensionUpdate {
    public static func validate(previous: SignedExtensionIdentity, version: String, candidate: SignedExtensionIdentity, candidateVersion: String) throws {
        guard previous.format == "CRX3", candidate.format == "CRX3",
              previous.extensionID == candidate.extensionID,
              previous.publicKeySHA256 == candidate.publicKeySHA256 else {
            throw ExtensionValidationError.invalid("The update must be signed by the installed extension's developer key.")
        }
        guard try ExtensionVersion(version) < ExtensionVersion(candidateVersion) else {
            throw ExtensionValidationError.invalid("The update version must be newer than the installed version.")
        }
    }
}
/// Commit point is atomic replacement of the registry. New bytes exist first;
/// old bytes remain available until the host completes activation and cleanup.
public enum ExtensionPackageStorage {
    public static func directory(root: URL, recordID: UUID, versionID: UUID?) -> URL {
        if let versionID { return root.appendingPathComponent("Versions").appendingPathComponent(versionID.uuidString) }
        return root.appendingPathComponent(recordID.uuidString)
    }
    public static func commitPrepared(_ candidate: URL, root: URL, versionID: UUID, registry: Data) throws {
        let parent = root.appendingPathComponent("Versions")
        try FileManager.default.createDirectory(at: parent, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
        let destination = parent.appendingPathComponent(versionID.uuidString)
        try FileManager.default.moveItem(at: candidate, to: destination)
        do { try registry.write(to: root.appendingPathComponent("extensions.json"), options: .atomic) }
        catch { try? FileManager.default.removeItem(at: destination); throw error }
    }
}
