import Foundation

/// Resource URL shape is separate from verified publisher/native-host identity.
public enum ExtensionResourceOrigin {
    public static func isExtensionScheme(_ scheme:String?)->Bool {
        guard let scheme else{return false}
        return ["webkit-extension","moz-extension"].contains(scheme.lowercased())
    }
    public static func isValidBaseURL(_ url:URL)->Bool {
        isExtensionScheme(url.scheme) && !(url.host ?? "").isEmpty && url.user==nil && url.password==nil && url.port==nil && url.query==nil && url.fragment==nil && ["","/"].contains(url.path)
    }
    public static func initialURL(sourceExtension:String,id:UUID)->URL? {
        guard sourceExtension.lowercased()=="xpi" else{return nil}
        return URL(string:"moz-extension://"+id.uuidString.lowercased()+"/")
    }
}
