import AppKit
import WebKit
import Observation
import SereinCore

struct InstalledExtension: Identifiable, Codable {
    var id: UUID
    var name: String
    var version: String
    var enabled: Bool
    var permissions: [String]
    var hosts: [String]
    var permissionState: ExtensionPermissionState? = nil
}
@MainActor @Observable final class ExtensionHost: NSObject {
    let controller=WKWebExtensionController()
    var records: [InstalledExtension] = []
    var error: String?
    var actionRevision=0
    @ObservationIgnored var contexts: [UUID:WKWebExtensionContext] = [:]
    @ObservationIgnored weak var manager: BrowserManager?
    let root: URL
    init(root: URL) {
        self.root=root;super.init();controller.delegate=self
        do {
            try FileManager.default.createDirectory(at:root,withIntermediateDirectories:true)
            let url=root.appendingPathComponent("extensions.json")
            if FileManager.default.fileExists(atPath:url.path) {records=try JSONDecoder().decode([InstalledExtension].self,from:Data(contentsOf:url))}
        } catch {self.error=error.localizedDescription}
        for name in [WKWebExtensionContext.permissionsWereGrantedNotification,
                     WKWebExtensionContext.permissionsWereDeniedNotification, WKWebExtensionContext.grantedPermissionsWereRemovedNotification,
                     WKWebExtensionContext.deniedPermissionsWereRemovedNotification, WKWebExtensionContext.permissionMatchPatternsWereGrantedNotification,
                     WKWebExtensionContext.permissionMatchPatternsWereDeniedNotification, WKWebExtensionContext.grantedPermissionMatchPatternsWereRemovedNotification,
                     WKWebExtensionContext.deniedPermissionMatchPatternsWereRemovedNotification] {
            NotificationCenter.default.addObserver(self,selector:#selector(permissionsChanged(_:)),name:name,object:nil)
        }
    }
    @objc private func permissionsChanged(_ notification: Notification) {
        guard let context=notification.object as? WKWebExtensionContext else{return}
        rememberPermissions(context)
    }
    func rememberPermissions(_ context: WKWebExtensionContext) {
        guard let id=contexts.first(where:{$0.value===context})?.key,
              let index=records.firstIndex(where:{$0.id==id}) else{return}
        records[index].permissionState=ExtensionPermissionState(context)
        save()
    }
    func restore() async {
        for record in records where record.enabled {
            do {try await load(record)} catch {self.error="\(record.name): \(error.localizedDescription)"}
        }
    }
    func save() {
        do {try JSONEncoder().encode(records).write(to:root.appendingPathComponent("extensions.json"),options:.atomic)} catch {self.error=error.localizedDescription}
    }
    func load(_ record: InstalledExtension) async throws {
        guard contexts[record.id] == nil else { return }
        let directory=root.appendingPathComponent(record.id.uuidString)
        let manifest=try ExtensionManifest(data:Data(contentsOf:directory.appendingPathComponent("manifest.json")))
        let ext=try await WKWebExtension(resourceBaseURL:directory)
        try manifest.validateRequiredPermissions(recognized:Set(ext.requestedPermissions.map(\.rawValue)))
        guard ext.errors.isEmpty else{throw ExtensionValidationError.invalid(ext.errors.map(\.localizedDescription).joined(separator:"\n"))}
        let context=WKWebExtensionContext(for:ext);context.uniqueIdentifier=record.id.uuidString
        context.hasAccessToPrivateData=false
        for permission in ext.requestedPermissions where record.permissions.contains(permission.rawValue) {context.setPermissionStatus(.grantedExplicitly,for:permission)}
        for pattern in ext.requestedPermissionMatchPatterns where record.hosts.contains(pattern.string) {context.setPermissionStatus(.grantedExplicitly,for:pattern)}
        if let state=record.permissionState {try state.apply(to:context)}
        try controller.load(context);contexts[record.id]=context
        for window in manager?.windows ?? [] where !window.session.state.isPrivate {
            if let bridge=window.session.extensionWindow {context.didOpenWindow(bridge)}
        }
    }
    func chooseInstall(in session: BrowserSession) {
        guard !session.state.isPrivate,let window=session.window else{return}
        let panel=NSOpenPanel();panel.canChooseFiles=true;panel.canChooseDirectories=true;panel.allowsMultipleSelection=false
        panel.message="Choose an unpacked WebExtension folder, ZIP, or XPI. Native Safari App Extensions and CRX signatures are not supported."
        panel.beginSheetModal(for:window){[weak self,weak session] response in
            guard response == .OK,let url=panel.url,let self,let session else{return}
            Task {await self.install(url,in:session)}
        }
    }
    func install(_ source: URL,in session: BrowserSession) async {
        let access=source.startAccessingSecurityScopedResource();defer{if access{source.stopAccessingSecurityScopedResource()}}
        let id=UUID(),destination=root.appendingPathComponent(UUID().uuidString+".staging")
        do {
            try prepare(source,at:destination)
            let manifestURL=destination.appendingPathComponent("manifest.json")
            let manifest=try ExtensionManifest(data:Data(contentsOf:manifestURL))
            let ext=try await WKWebExtension(resourceBaseURL:destination)
            guard ext.errors.isEmpty else{throw ExtensionValidationError.invalid(ext.errors.map(\.localizedDescription).joined(separator:"\n"))}
            try manifest.validateRequiredPermissions(recognized:Set(ext.requestedPermissions.map(\.rawValue)))
            let permissions=ext.requestedPermissions.map(\.rawValue).sorted(),hosts=ext.requestedPermissionMatchPatterns.map(\.string).sorted()
            let details="Version: \(ext.version ?? "Unknown")\n\nPermissions:\n\(permissions.joined(separator:"\n"))\n\nWebsite access:\n\(hosts.joined(separator:"\n"))\n\nThe package's publisher signature has not been verified. Install only if you trust its source. Private browsing access is disabled."
            let allowed=await withCheckedContinuation{continuation in session.confirm("Install \(ext.displayName ?? "extension")?",detail:details,yes:"Install"){continuation.resume(returning:$0)}}
            guard allowed else {try FileManager.default.removeItem(at:destination);return}
            let final=root.appendingPathComponent(id.uuidString);try FileManager.default.moveItem(at:destination,to:final)
            let record=InstalledExtension(id:id,name:ext.displayName ?? "Extension",version:ext.version ?? "Unknown",enabled:true,permissions:permissions,hosts:hosts)
            do {try await load(record);records.append(record);save()}
            catch {try? FileManager.default.removeItem(at:final);throw error}
        } catch {try? FileManager.default.removeItem(at:destination);self.error=error.localizedDescription}
    }
    func prepare(_ source: URL,at destination: URL) throws {
        let values=try source.resourceValues(forKeys:[.isDirectoryKey,.isSymbolicLinkKey])
        guard values.isSymbolicLink != true else{throw ExtensionValidationError.invalid("Symbolic-link packages are not accepted.")}
        if values.isDirectory==true {
            let enumerator=FileManager.default.enumerator(at:source,includingPropertiesForKeys:[.isSymbolicLinkKey,.fileSizeKey])
            var size=0,count=0
            while let file=enumerator?.nextObject() as? URL {
                let info=try file.resourceValues(forKeys:[.isSymbolicLinkKey,.fileSizeKey]);size+=info.fileSize ?? 0;count+=1
                guard info.isSymbolicLink != true,size<128*1024*1024,count<10_000 else{throw ExtensionValidationError.invalid("The package contains links or exceeds the resource limit.")}
            }
            try FileManager.default.copyItem(at:source,to:destination)
        } else {
            guard ["zip","xpi"].contains(source.pathExtension.lowercased()) else{throw ExtensionValidationError.invalid("Select a ZIP, XPI, or unpacked manifest folder. Signed CRX and native Safari formats are not implemented.")}
            try ExtensionArchive.validate(Data(contentsOf:source))
            try FileManager.default.createDirectory(at:destination,withIntermediateDirectories:true)
            let process=Process();process.executableURL=URL(fileURLWithPath:"/usr/bin/ditto");process.arguments=["-x","-k",source.path,destination.path]
            try process.run();process.waitUntilExit()
            guard process.terminationStatus==0 else{throw ExtensionValidationError.invalid("The system could not extract the extension.")}
            if !FileManager.default.fileExists(atPath:destination.appendingPathComponent("manifest.json").path) {
                let children=try FileManager.default.contentsOfDirectory(at:destination,includingPropertiesForKeys:[.isDirectoryKey]).filter{!$0.lastPathComponent.hasPrefix(".") && $0.lastPathComponent != "__MACOSX"}
                if children.count==1,let wrapper=children.first,FileManager.default.fileExists(atPath:wrapper.appendingPathComponent("manifest.json").path) {
                    for child in try FileManager.default.contentsOfDirectory(at:wrapper,includingPropertiesForKeys:nil) {try FileManager.default.moveItem(at:child,to:destination.appendingPathComponent(child.lastPathComponent))}
                    try FileManager.default.removeItem(at:wrapper)
                }
            }
        }
    }
    func setEnabled(_ id: UUID,_ enabled: Bool) async {
        guard let i=records.firstIndex(where:{$0.id==id}) else{return}
        do {
            if enabled {try await load(records[i])}
            else if let context=contexts[id] {rememberPermissions(context);try controller.unload(context);contexts[id]=nil}
            records[i].enabled=enabled;save()
        } catch {self.error=error.localizedDescription}
    }
    func remove(_ id: UUID) async {
        do {
            if let context=contexts[id] {
                try controller.unload(context)
            }
            contexts[id]=nil
            // Disabled extensions have no live context, but retain storage. Removal
            // must erase their data by the durable identity as well.
            // Session storage belongs to the unloaded context, not an on-disk
            // record. Querying it after unload produces WebKit storage errors.
            let persistentTypes=WKWebExtensionController.allExtensionDataTypes.subtracting([.session])
            let dataRecords=await controller.dataRecords(ofTypes:persistentTypes)
            let matching=dataRecords.filter{$0.uniqueIdentifier==id.uuidString}
            await controller.removeData(ofTypes:persistentTypes,from:matching)
            let removalErrors=matching.flatMap(\.errors)
            guard removalErrors.isEmpty else {
                throw ExtensionValidationError.invalid("Extension data could not be removed: " + removalErrors.map(\.localizedDescription).joined(separator:"; "))
            }
            try FileManager.default.removeItem(at:root.appendingPathComponent(id.uuidString));records.removeAll{$0.id==id};save()
        } catch {self.error=error.localizedDescription}
    }
    func perform(_ id: UUID,in session: BrowserSession) {
        guard let context=contexts[id],let tab=session.state.selectedTabID else{return}
        context.userGesturePerformed(in:session.bridge(tab));context.performAction(for:session.bridge(tab))
    }
    func setCurrentSite(_ id: UUID,in session: BrowserSession,allow: Bool) {
        guard let context=contexts[id],let url=session.current?.webView.url else{return}
        context.setPermissionStatus(allow ? .grantedExplicitly : .deniedExplicitly,for:url)
        rememberPermissions(context)
    }
}
