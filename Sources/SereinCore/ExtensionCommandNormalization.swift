import Foundation

public enum ExtensionCommandNormalization {
    /// Chrome/Firefox permit an empty reserved action command. WebKit rejects
    /// an empty object before recognizing its reserved name. Add only a label.
    /// Never alter permissions, executable code, shortcuts, or ordinary commands.
    public static func normalize(_ data: Data) throws -> Data {
        guard var manifest=try JSONSerialization.jsonObject(with:data) as? [String:Any],
              let version=manifest["manifest_version"] as? Int,
              var commands=manifest["commands"] as? [String:Any] else{return data}
        let actions: [String]=version == 3 ? ["_execute_action"] : version == 2 ? ["_execute_browser_action","_execute_page_action"] : []
        var changed=false
        for key in actions {
            if let command=commands[key] as? [String:Any],command.isEmpty {
                commands[key]=["description":"Activate extension"]
                changed=true
            }
        }
        guard changed else{return data}
        manifest["commands"]=commands
        return try JSONSerialization.data(withJSONObject:manifest,options:[.sortedKeys,.prettyPrinted])
    }
}
