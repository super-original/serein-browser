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
    init(granted: [String:Date], denied: [String:Date], grantedHosts: [String:Date], deniedHosts: [String:Date]) {
        self.granted = granted; self.denied = denied; self.grantedHosts = grantedHosts; self.deniedHosts = deniedHosts
    }
    @MainActor func updating(from record: InstalledExtension, to ext: WKWebExtension) throws -> Self {
        var result = self
        let now = Date()
        let required = Set(ext.requestedPermissions.map(\.rawValue))
        let available = required.union(ext.optionalPermissions.map(\.rawValue))
        result.granted = granted.filter { available.contains($0.key) && $0.value > now }
        result.denied = denied.filter { available.contains($0.key) && $0.value > now }
        for permission in required.subtracting(record.permissions) where result.denied[permission] == nil {
            result.granted[permission] = .distantFuture
        }
        let allowed = ext.requestedPermissionMatchPatterns.union(ext.optionalPermissionMatchPatterns)
        result.grantedHosts = try grantedHosts.filter { entry in
            guard entry.value > now else { return false }
            let pattern = try WKWebExtension.MatchPattern(string: entry.key)
            return allowed.contains { $0.matches(pattern) }
        }
        // Retain all explicit site denials, including narrower exceptions to a new host grant.
        result.deniedHosts = deniedHosts.filter { $0.value > now }
        let newHosts = Set(ext.requestedPermissionMatchPatterns.map(\.string)).subtracting(record.hosts)
        for host in newHosts where result.deniedHosts[host] == nil { result.grantedHosts[host] = .distantFuture }
        return result
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
