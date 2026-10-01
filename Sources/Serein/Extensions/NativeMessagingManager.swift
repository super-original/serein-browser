import AppKit
import WebKit
import Observation
import UniformTypeIdentifiers
import SereinCore

struct NativeHostRegistration:Codable,Identifiable {
    var id=UUID()
    let recordID:UUID
    let extensionID:String
    let publicKeySHA256:String
    let manifest:NativeHostManifest
}

/// Explicit registrations only. No lookup in another browser's host directories
/// and no execution from a manifest supplied by an extension API call.
@MainActor @Observable final class NativeMessagingManager {
    private(set) var registrations:[NativeHostRegistration]=[]
    @ObservationIgnored private weak var host:ExtensionHost?
    @ObservationIgnored private let file:URL
    private struct Connection {
        let recordID:UUID
        let context:WKWebExtensionContext
        let registrationID:UUID
        let transport:NativeMessageTransport
        let port:WKWebExtension.MessagePort?
    }
    @ObservationIgnored private var connections:[UUID:Connection]=[:]
    @ObservationIgnored private var shuttingDown=false
    var hasConnections:Bool{!connections.isEmpty}
    func resumeAcceptingConnections(){shuttingDown=false}
    func shutdown() async {
        shuttingDown=true
        let pending=Array(connections.values)
        for id in Array(connections.keys){stop(id)}
        for connection in pending {await connection.transport.close()}
    }
    init(host:ExtensionHost) {
        self.host=host;file=host.root.appendingPathComponent("native-hosts.json")
        do {
            if FileManager.default.fileExists(atPath:file.path) {
                let data=try Data(contentsOf:file)
                guard data.count<=4*1024*1024 else{throw ExtensionValidationError.invalid("Native-host registry exceeds 4 MiB.")}
                registrations=try JSONDecoder().decode([NativeHostRegistration].self,from:data)
            }
        } catch {host.error="Native hosts could not be restored: \(error.localizedDescription)"}
    }
    func registrations(for id:UUID)->[NativeHostRegistration]{registrations.filter{$0.recordID==id}}
    func activeConnectionCount(for id:UUID)->Int{connections.values.filter{$0.recordID==id}.count}
    private func save(_ proposed:[NativeHostRegistration]) throws {
        try PrivateFileStore.write(JSONEncoder().encode(proposed),to:file)
        registrations=proposed
    }
    func chooseRegistration(for record:InstalledExtension,in session:BrowserSession) {
        guard !session.state.isPrivate,let window=session.dialogWindow,let identity=record.packageIdentity,identity.format=="CRX3" else{return}
        host?.error=nil
        let panel=NSOpenPanel();panel.allowedContentTypes=[.json];panel.allowsMultipleSelection=false
        panel.message="Choose an installed native application's Chrome host manifest. Its allowed origins must include this signed extension."
        panel.beginSheetModal(for:window){[weak self,weak session] response in
            guard response == .OK,let source=panel.url,let self,let session else{return}
            self.reviewRegistration(source,for:record,in:session)
        }
    }
    /// Shared review after file selection; validation and consent also apply to
    /// controlled fixture URLs supplied independently of file-picker automation.
    func reviewRegistration(_ source:URL,for record:InstalledExtension,in session:BrowserSession) {
        guard !session.state.isPrivate,session.dialogWindow != nil,let identity=record.packageIdentity,identity.format=="CRX3" else{return}
        host?.error=nil
        do {
            let access=source.startAccessingSecurityScopedResource();defer{if access{source.stopAccessingSecurityScopedResource()}}
            guard try source.resourceValues(forKeys:[.isRegularFileKey]).isRegularFile==true else{throw ExtensionValidationError.invalid("Choose a regular JSON manifest file.")}
            let file=try FileHandle(forReadingFrom:source);defer{try? file.close()}
            let manifest=try NativeHostManifest(data:file.read(upToCount:1024*1024+1) ?? Data())
            _=try manifest.origin(for:identity)
            guard FileManager.default.isExecutableFile(atPath:manifest.path) else{throw ExtensionValidationError.invalid("The native application's executable was not found or is not executable.")}
            session.confirm("Allow this native application?",detail:"\(record.name) will be able to exchange messages with \(manifest.name).\n\nExecutable:\n\(manifest.path)\n\nNative applications run with your account's access. Only register an application you installed and trust.",yes:"Allow") { [weak self] allowed in
                guard allowed,let self else{return}
                do {
                    guard let current=self.host?.records.first(where:{$0.id==record.id}),current.packageIdentity==record.packageIdentity else{throw ExtensionValidationError.invalid("The extension changed while native-host consent was open.")}
                    try self.register(manifest,for:current)
                } catch {self.host?.error=error.localizedDescription}
            }
        } catch {host?.error=error.localizedDescription}
    }
    /// Called after explicit consent, or by controlled fixture setup.
    func register(_ manifest:NativeHostManifest,for record:InstalledExtension) throws {
        guard let identity=record.packageIdentity else{throw ExtensionValidationError.invalid("Native hosts currently require a verified CRX3 identity.")}
        _=try manifest.origin(for:identity)
        guard FileManager.default.isExecutableFile(atPath:manifest.path) else{throw ExtensionValidationError.invalid("The registered native executable is unavailable.")}
        let previous=registrations.filter{$0.recordID==record.id && $0.manifest.name==manifest.name}
        var proposed=registrations.filter{$0.recordID != record.id || $0.manifest.name != manifest.name}
        proposed.append(.init(recordID:record.id,extensionID:identity.extensionID,publicKeySHA256:identity.publicKeySHA256,manifest:manifest))
        try save(proposed);host?.error=nil
        for old in previous {stop(registrationID:old.id)}
    }
    func revoke(_ id:UUID) {
        registrations.removeAll{$0.id==id};stop(registrationID:id)
        do {try save(registrations);host?.error=nil}
        catch {host?.error="Native access was revoked for this session, but the change could not be saved: \(error.localizedDescription)"}
    }
    func removeRegistrations(for id:UUID){for registration in registrations(for:id){revoke(registration.id)}}
    private func authorized(_ context:WKWebExtensionContext,name:String?) throws -> (InstalledExtension,NativeHostRegistration,String) {
        guard let host,let id=host.contexts.first(where:{$0.value===context})?.key,
              let record=host.records.first(where:{$0.id==id && $0.enabled}),let identity=record.packageIdentity,
              host.manifestAPIPermissions[id]?.contains("nativeMessaging")==true,
              context.hasPermission(WKWebExtension.Permission(rawValue:"nativeMessaging")),
              let name,let registration=registrations.first(where:{$0.recordID==id && $0.manifest.name==name && $0.extensionID==identity.extensionID && $0.publicKeySHA256==identity.publicKeySHA256}) else {
            throw ExtensionValidationError.invalid("Native messaging requires an original manifest declaration, current permission and a registered host for this verified extension identity.")
        }
        return (record,registration,try registration.manifest.origin(for:identity))
    }
    private func create(_ context:WKWebExtensionContext,name:String?,port:WKWebExtension.MessagePort?) throws -> UUID {
        guard !shuttingDown else{throw NativeMessageTransportError.unavailable}
        let (record,registration,origin)=try authorized(context,name:name)
        guard connections.count<16,activeConnectionCount(for:record.id)<4 else{throw ExtensionValidationError.invalid("Too many native-host connections are active.")}
        let transport=NativeMessageTransport(executable:URL(fileURLWithPath:registration.manifest.path),arguments:[origin],maximumLifetime:port==nil ? 30 : nil)
        let id=UUID();connections[id]=Connection(recordID:record.id,context:context,registrationID:registration.id,transport:transport,port:port)
        return id
    }
    private func stillAuthorized(_ connection:Connection)->Bool {
        guard let registration=registrations.first(where:{$0.id==connection.registrationID}) else{return false}
        return (try? authorized(connection.context,name:registration.manifest.name)) != nil
    }
    func cancelUnauthorized(){for (id,connection) in connections where !stillAuthorized(connection){stop(id)}}
    func stop(context:WKWebExtensionContext){for (id,connection) in connections where connection.context===context{stop(id)}}
    private func stop(registrationID:UUID){for (id,connection) in connections where connection.registrationID==registrationID{stop(id)}}
    private func stop(_ id:UUID,error:(any Error)?=nil) {
        guard let connection=connections[id] else{return}
        connection.port?.messageHandler=nil;connection.port?.disconnectHandler=nil
        connection.transport.cancel()
        if let error {connection.port?.disconnect(throwing:error)} else {connection.port?.disconnect()}
    }
    func send(_ message:Any,name:String?,context:WKWebExtensionContext,reply:@escaping (Any?,(any Error)?)->Void) {
        do {
            _=try authorized(context,name:name)
            let frame=try NativeMessageFraming.encode(message)
            let id=try create(context,name:name,port:nil)
            guard let connection=connections[id] else{throw NativeMessageTransportError.unavailable}
            Task {
                do {
                    try connection.transport.send(frame);connection.transport.start()
                    var iterator=connection.transport.messages.makeAsyncIterator()
                    guard let response=try await iterator.next(),stillAuthorized(connection) else{throw NativeMessageTransportError.unavailable}
                    reply(try JSONSerialization.jsonObject(with:response,options:.fragmentsAllowed),nil)
                } catch {reply(nil,error)}
                await connection.transport.close();connections[id]=nil
            }
        } catch {reply(nil,error)}
    }
    func connect(_ port:WKWebExtension.MessagePort,context:WKWebExtensionContext,completion:@escaping ((any Error)?)->Void) {
        do {
            let id=try create(context,name:port.applicationIdentifier,port:port)
            guard let connection=connections[id] else{throw NativeMessageTransportError.unavailable}
            port.messageHandler={ [weak self] message,error in
                guard let self else{return}
                do {
                    guard error==nil,self.stillAuthorized(connection) else{throw error ?? NativeMessageTransportError.unavailable}
                    try connection.transport.send(NativeMessageFraming.encode(message ?? NSNull()))
                } catch {self.stop(id,error:error)}
            }
            port.disconnectHandler={ [weak self] _ in self?.stop(id) }
            connection.transport.start();completion(nil)
            Task {
                do {
                    for try await message in connection.transport.messages {
                        guard stillAuthorized(connection),!port.isDisconnected else{throw NativeMessageTransportError.unavailable}
                        let object=try JSONSerialization.jsonObject(with:message,options:.fragmentsAllowed)
                        try await port.sendMessage(object)
                    }
                    port.disconnect()
                } catch {port.disconnect(throwing:error)}
                port.messageHandler=nil;port.disconnectHandler=nil
                await connection.transport.close();connections[id]=nil
            }
        } catch {completion(error)}
    }
}
