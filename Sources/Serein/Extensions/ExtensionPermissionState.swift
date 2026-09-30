import Foundation
import WebKit

/// Explicit engine permissions only; tab-scoped activeTab/user gestures are never persisted.
struct ExtensionPermissionState: Codable {
    var granted: [String:Date]
    var denied: [String:Date]
    var grantedHosts: [String:Date]
    var deniedHosts: [String:Date]

    @MainActor init(_ context: WKWebExtensionContext) {
        granted=Dictionary(uniqueKeysWithValues:context.grantedPermissions.map{($0.key.rawValue,$0.value)})
        denied=Dictionary(uniqueKeysWithValues:context.deniedPermissions.map{($0.key.rawValue,$0.value)})
        grantedHosts=Dictionary(uniqueKeysWithValues:context.grantedPermissionMatchPatterns.map{($0.key.string,$0.value)})
        deniedHosts=Dictionary(uniqueKeysWithValues:context.deniedPermissionMatchPatterns.map{($0.key.string,$0.value)})
    }
    @MainActor func apply(to context: WKWebExtensionContext) throws {
        let now=Date()
        func permissions(_ values:[String:Date])->[WKWebExtension.Permission:Date] {
            Dictionary(uniqueKeysWithValues:values.filter{$0.value>now}.map{(WKWebExtension.Permission(rawValue:$0.key),$0.value)})
        }
        func patterns(_ values:[String:Date]) throws -> [WKWebExtension.MatchPattern:Date] {
            try Dictionary(uniqueKeysWithValues:values.filter{$0.value>now}.map{(try WKWebExtension.MatchPattern(string:$0.key),$0.value)})
        }
        // Replace initial installation grants. A removed grant must not return on restart.
        context.grantedPermissions=permissions(granted)
        context.deniedPermissions=permissions(denied)
        context.grantedPermissionMatchPatterns=try patterns(grantedHosts)
        context.deniedPermissionMatchPatterns=try patterns(deniedHosts)
    }
}
