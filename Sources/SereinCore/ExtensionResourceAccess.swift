import Foundation

/// Preflight for page-initiated top-level origin transitions. WebKit remains
/// responsible for serving resources and for subresource/frame access checks.
public enum ExtensionResourceAccess {
    public static func allows(path: String, manifest: [String:Any], sourceExtensionID: String?, originMatches: (String)->Bool) -> Bool {
        let path=path.hasPrefix("/") ? String(path.dropFirst()) : path
        guard !path.isEmpty,!path.contains("\\"),!path.contains("\0"),!path.split(separator:"/").contains("..") else{return false}
        func matches(_ patterns:[String]) -> Bool {
            patterns.contains { pattern in
                let relative=pattern.hasPrefix("/") ? String(pattern.dropFirst()) : pattern
                let expression="(?s)\\A"+NSRegularExpression.escapedPattern(for:relative).replacingOccurrences(of:"\\*",with:".*")+"\\z"
                return path.range(of:expression,options:.regularExpression) != nil
            }
        }
        if manifest["manifest_version"] as? Int == 2 {
            return matches(manifest["web_accessible_resources"] as? [String] ?? [])
        }
        guard manifest["manifest_version"] as? Int == 3,let rules=manifest["web_accessible_resources"] as? [[String:Any]] else{return false}
        return rules.contains { rule in
            // A persistent origin is not the per-session dynamic origin promised
            // by Chrome. Do not treat a static URL as a valid dynamic resource.
            guard rule["use_dynamic_url"] as? Bool != true,matches(rule["resources"] as? [String] ?? []) else{return false}
            if let sourceExtensionID {
                let ids=rule["extension_ids"] as? [String] ?? []
                return ids.contains("*") || ids.contains(sourceExtensionID)
            }
            return (rule["matches"] as? [String] ?? []).contains(where:originMatches)
        }
    }
}
