import Foundation

/// Preflight for page-initiated top-level origin transitions. WebKit remains
/// responsible for serving resources and for subresource/frame access checks.
public enum ExtensionResourceAccess {
    // Glob '*' is the only operator. Avoid regex backtracking for extension-
    // supplied patterns and page-supplied paths on the browser's main thread.
    private static func wildcard(_ pattern:String,matches value:String)->Bool {
        let pattern=Array(pattern.utf8),value=Array(value.utf8)
        var p=0,v=0,retry=0
        var star:Int?
        while v<value.count {
            if p<pattern.count,pattern[p]==42 {star=p;p += 1;retry=v}
            else if p<pattern.count,pattern[p]==value[v] {p += 1;v += 1}
            else if let star {retry += 1;v=retry;p=star+1}
            else{return false}
        }
        while p<pattern.count,pattern[p]==42 {p += 1}
        return p==pattern.count
    }
    public static func allows(path: String, manifest: [String:Any], sourceExtensionID: String?, originMatches: (String)->Bool) -> Bool {
        let path=path.hasPrefix("/") ? String(path.dropFirst()) : path
        guard !path.isEmpty,!path.contains("\\"),!path.contains("\0"),!path.split(separator:"/").contains("..") else{return false}
        func matches(_ patterns:[String]) -> Bool {
            patterns.contains { pattern in
                let relative=pattern.hasPrefix("/") ? String(pattern.dropFirst()) : pattern
                return wildcard(relative,matches:path)
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
