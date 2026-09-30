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
    var packageIdentity: SignedExtensionIdentity? = nil
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
        try controller.load(context);contexts[record.id]=context;actionRevision += 1
        for window in manager?.windows ?? [] where !window.session.state.isPrivate {
            if let bridge=window.session.extensionWindow {context.didOpenWindow(bridge)}
        }
    }
    func chooseInstall(in session: BrowserSession) {
        guard !session.state.isPrivate,let window=session.dialogWindow else{return}
        let panel=NSOpenPanel();panel.canChooseFiles=true;panel.canChooseDirectories=true;panel.allowsMultipleSelection=false
        panel.message="Choose an unpacked WebExtension folder, ZIP, XPI, or signed CRX3. Native Safari App Extensions and legacy CRX2 are not supported."
        panel.beginSheetModal(for:window){[weak self,weak session] response in
            guard response == .OK,let url=panel.url,let self,let session else{return}
            Task {await self.install(url,in:session)}
        }
    }
    func install(_ source: URL,in session: BrowserSession) async {
        guard !session.state.isPrivate else { error = "Extensions cannot be installed from a private window."; return }
        let access=source.startAccessingSecurityScopedResource();defer{if access{source.stopAccessingSecurityScopedResource()}}
        let id=UUID(),destination=root.appendingPathComponent(UUID().uuidString+".staging")
        do {
            let identity = try prepare(source,at:destination)
            if let identity, records.contains(where: { $0.packageIdentity?.extensionID == identity.extensionID }) {
                throw ExtensionValidationError.invalid("This CRX3 developer identity is already installed. Signed updates are not implemented.")
            }
            let manifestURL=destination.appendingPathComponent("manifest.json")
            let manifest=try ExtensionManifest(data:Data(contentsOf:manifestURL))
            let ext=try await WKWebExtension(resourceBaseURL:destination)
            guard ext.errors.isEmpty else{throw ExtensionValidationError.invalid(ext.errors.map(\.localizedDescription).joined(separator:"\n"))}
            try manifest.validateRequiredPermissions(recognized:Set(ext.requestedPermissions.map(\.rawValue)))
            let permissions=ext.requestedPermissions.map(\.rawValue).sorted(),hosts=ext.requestedPermissionMatchPatterns.map(\.string).sorted()
            let provenance = identity.map { "Original CRX3 archive signature verified. Developer ID: \($0.extensionID). This is self-signed integrity, not Chrome Web Store approval. Normalized installed files are not the signed archive." } ?? "The package publisher signature has not been verified."
            let details="Version: \(ext.version ?? "Unknown")\n\nPermissions:\n\(permissions.joined(separator:"\n"))\n\nWebsite access:\n\(hosts.joined(separator:"\n"))\n\nEmpty reserved action-command metadata is normalized for WebKit when needed. The original source package is unchanged.\n\n\(provenance) Install only if you trust its source. Private browsing access is disabled."
            let allowed=await withCheckedContinuation{continuation in session.confirm("Install \(ext.displayName ?? "extension")?",detail:details,yes:"Install"){continuation.resume(returning:$0)}}
            guard allowed else {try FileManager.default.removeItem(at:destination);return}
            if let identity, records.contains(where: { $0.packageIdentity?.extensionID == identity.extensionID }) {
                throw ExtensionValidationError.invalid("This CRX3 developer identity was installed while consent was pending.")
            }
            let final=root.appendingPathComponent(id.uuidString);try FileManager.default.moveItem(at:destination,to:final)
            let record=InstalledExtension(id:id,name:ext.displayName ?? "Extension",version:ext.version ?? "Unknown",enabled:true,permissions:permissions,hosts:hosts,packageIdentity:identity)
            do {try await load(record);records.append(record);save()}
            catch {try? FileManager.default.removeItem(at:final);throw error}
        } catch {try? FileManager.default.removeItem(at:destination);self.error=error.localizedDescription}
    }
    @discardableResult
    func prepare(_ source: URL,at destination: URL) throws -> SignedExtensionIdentity? {
        var identity: SignedExtensionIdentity?
        let values=try source.resourceValues(forKeys:[.isDirectoryKey,.isSymbolicLinkKey,.isRegularFileKey])
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
            guard values.isRegularFile == true else { throw ExtensionValidationError.invalid("Select a regular package file.") }
            guard ["zip","xpi","crx"].contains(source.pathExtension.lowercased()) else{throw ExtensionValidationError.invalid("Select a ZIP, XPI, CRX3, or unpacked manifest folder. Legacy CRX2 and native Safari formats are not implemented.")}
            let handle = try FileHandle(forReadingFrom: source)
            defer { try? handle.close() }
            let input = try handle.read(upToCount: CRXPackage.maximumPackageBytes + 1) ?? Data()
            guard input.count <= CRXPackage.maximumPackageBytes else { throw ExtensionValidationError.invalid("Package exceeds the size limit.") }
            let archive: Data
            if source.pathExtension.lowercased() == "crx" {
                let package = try CRXPackage.verify(input)
                archive = package.archive; identity = package.identity
            } else { try ExtensionArchive.validate(input); archive = input }
            // Extract the checked bytes, never reopen the user-controlled source path.
            let snapshotRoot = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
            try FileManager.default.createDirectory(at: snapshotRoot, withIntermediateDirectories: false, attributes: [.posixPermissions: 0o700])
            defer { try? FileManager.default.removeItem(at: snapshotRoot) }
            let snapshot = snapshotRoot.appendingPathComponent("verified.zip")
            try archive.write(to: snapshot, options: .atomic)
            try FileManager.default.createDirectory(at:destination,withIntermediateDirectories:true)
            let process=Process();process.executableURL=URL(fileURLWithPath:"/usr/bin/ditto");process.arguments=["-x","-k",snapshot.path,destination.path]
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
        let manifestURL=destination.appendingPathComponent("manifest.json")
        let original=try Data(contentsOf:manifestURL)
        let normalized=try ExtensionCommandNormalization.normalize(original)
        if normalized != original {try normalized.write(to:manifestURL,options:.atomic)}
        return identity
    }
    func setEnabled(_ id: UUID,_ enabled: Bool) async {
        guard let i=records.firstIndex(where:{$0.id==id}) else{return}
        do {
            if enabled {try await load(records[i])}
            else if let context=contexts[id] {rememberPermissions(context);try controller.unload(context);contexts[id]=nil}
            records[i].enabled=enabled;save()
        } catch {self.error=error.localizedDescription}
    }
    func confirmRemoval(_ record: InstalledExtension,in session: BrowserSession) {
        session.confirm("Remove \(record.name)?",detail:"The package and extension settings will be removed. Some extension website data may remain; use Clear Website Data in Settings to remove it.",yes:"Remove") { [weak self] yes in
            if yes {Task {await self?.remove(record.id)}}
        }
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
    func actionEnabled(_ id: UUID,in session: BrowserSession) -> Bool {
        _=actionRevision
        return contexts[id]?.action(for:session.state.selectedTabID.map{session.bridge($0)})?.isEnabled ?? false
    }
    func performFromLibrary(_ id: UUID,in session: BrowserSession) async {
        session.libraryPanel=nil
        for _ in 0..<40 {
            guard let window=session.window else{return}
            if window.attachedSheet == nil {perform(id,in:session);return}
            try? await Task.sleep(for:.milliseconds(50))
        }
        error="Close the current dialog before opening the extension action."
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
