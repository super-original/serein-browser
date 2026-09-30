import Foundation

/// A Chrome-format native host declaration. Authorization also requires a
/// verified package identity, browser permission and explicit user registration;
/// parsing this file alone never authorizes executing its path.
public struct NativeHostManifest:Codable,Equatable,Sendable {
    public let name:String
    public let description:String
    public let path:String
    public let type:String
    public let allowedOrigins:[String]
    private enum CodingKeys:String,CodingKey {case name,description,path,type;case allowedOrigins="allowed_origins"}
    public init(data:Data) throws {
        guard data.count<=1024*1024 else{throw ExtensionValidationError.invalid("Native host manifest exceeds 1 MiB.")}
        self=try JSONDecoder().decode(Self.self,from:data)
    }
    public init(from decoder:any Decoder) throws {
        let values=try decoder.container(keyedBy:CodingKeys.self)
        name=try values.decode(String.self,forKey:.name)
        description=try values.decode(String.self,forKey:.description)
        path=try values.decode(String.self,forKey:.path)
        type=try values.decode(String.self,forKey:.type)
        allowedOrigins=try values.decode([String].self,forKey:.allowedOrigins)
        guard !name.isEmpty,name.utf8.allSatisfy({(97...122).contains($0) || (48...57).contains($0) || $0==95 || $0==46}),
              !name.hasPrefix("."),!name.hasSuffix("."),!name.contains(".."),
              type=="stdio",path.hasPrefix("/"),!path.contains("\0"),!description.isEmpty,
              !allowedOrigins.isEmpty,allowedOrigins.allSatisfy(Self.validOrigin) else {
            throw ExtensionValidationError.invalid("Invalid native host name, executable path, stdio type or allowed Chrome origins. Firefox native-host manifests are not supported yet.")
        }
    }
    private static func validOrigin(_ value:String)->Bool {
        let prefix="chrome-extension://"
        guard value.hasPrefix(prefix),value.hasSuffix("/") else{return false}
        let identifier=value.dropFirst(prefix.count).dropLast()
        return identifier.utf8.count==32 && identifier.utf8.allSatisfy{(97...112).contains($0)}
    }
    public func origin(for identity:SignedExtensionIdentity) throws -> String {
        let origin="chrome-extension://"+identity.extensionID+"/"
        guard identity.format=="CRX3",Self.validOrigin(origin),allowedOrigins.contains(origin) else {
            throw ExtensionValidationError.invalid("The native host does not allow this signed Chrome extension identity.")
        }
        return origin
    }
}
