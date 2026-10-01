import Foundation
import WebKit
import SereinCore

@MainActor enum ExtensionPackageLoader {
    static func load(_ directory:URL) async throws -> WKWebExtension {
        let layout=try ExtensionPackageLayout.inspect(directory)
        if layout.isSafariBundle {
            guard let bundle=Bundle(url:directory) else{throw ExtensionValidationError.invalid("The Safari Web Extension bundle could not be opened.")}
            // Preserve the bundle and use WebKit's public bundle resource validation.
            // Never load its native executable or flatten it into unsigned resources.
            return try await WKWebExtension(appExtensionBundle:bundle)
        }
        return try await WKWebExtension(resourceBaseURL:directory)
    }
    static func manifest(_ directory:URL) throws -> URL {
        try ExtensionPackageLayout.inspect(directory).resources.appendingPathComponent("manifest.json")
    }
}
