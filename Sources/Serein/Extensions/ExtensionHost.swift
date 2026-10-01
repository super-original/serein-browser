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
    var contextIdentifier: String? = nil
    var packageVersionID: UUID? = nil
    var resourceBaseURL: URL? = nil
    var capabilityLedger: ExtensionCapabilityLedger? = nil
    func directory(in root: URL) -> URL { ExtensionPackageStorage.directory(root: root, recordID: id, versionID: packageVersionID) }
    var runtimeIdentifier: String { contextIdentifier ?? id.uuidString }
}
@MainActor @Observable final class ExtensionHost: NSObject {
    let controller=WKWebExtensionController()
    @ObservationIgnored lazy var nativeMessaging=NativeMessagingManager(host:self)
    var records: [InstalledExtension] = []
    var error: String?
    var actionRevision=0
    var contextErrors:[UUID:[String]]=[:]
    var busyIDs: Set<UUID> = []
    // Original validated declarations, distinct from any runtime transport grant.
    @ObservationIgnored var manifestAPIPermissions:[UUID:Set<String>]=[:]
    @ObservationIgnored var contexts: [UUID:WKWebExtensionContext] = [:]
    @ObservationIgnored weak var manager: BrowserManager?
    let root: URL
    init(root: URL) {
        self.root=root;super.init();controller.delegate=self
        do {
            try PrivateFileStore.prepareDirectory(root)
            let url=root.appendingPathComponent("extensions.json")
            if FileManager.default.fileExists(atPath:url.path) {records=try JSONDecoder().decode([InstalledExtension].self,from:Data(contentsOf:url))}
        } catch {self.error=error.localizedDescription}
        NotificationCenter.default.addObserver(self,selector:#selector(contextErrorsChanged(_:)),name:WKWebExtensionContext.errorsDidUpdateNotification,object:nil)
        for name in [WKWebExtensionContext.permissionsWereGrantedNotification,
                     WKWebExtensionContext.permissionsWereDeniedNotification, WKWebExtensionContext.grantedPermissionsWereRemovedNotification,
                     WKWebExtensionContext.deniedPermissionsWereRemovedNotification, WKWebExtensionContext.permissionMatchPatternsWereGrantedNotification,
                     WKWebExtensionContext.permissionMatchPatternsWereDeniedNotification, WKWebExtensionContext.grantedPermissionMatchPatternsWereRemovedNotification,
                     WKWebExtensionContext.deniedPermissionMatchPatternsWereRemovedNotification] {
            NotificationCenter.default.addObserver(self,selector:#selector(permissionsChanged(_:)),name:name,object:nil)
        }
    }
    @objc private func contextErrorsChanged(_ notification:Notification) {
        guard let context=notification.object as? WKWebExtensionContext,
              let id=contexts.first(where:{$0.value === context})?.key else{return}
        contextErrors[id]=context.errors.map(\.localizedDescription)
    }
    @objc private func permissionsChanged(_ notification: Notification) {
        guard let context=notification.object as? WKWebExtensionContext else{return}
        rememberPermissions(context)
        nativeMessaging.cancelUnauthorized()
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
        do {try PrivateFileStore.write(JSONEncoder().encode(records),to:root.appendingPathComponent("extensions.json"))} catch {self.error=error.localizedDescription}
    }
    func load(_ record: InstalledExtension) async throws {
        guard contexts[record.id] == nil else { return }
        let directory=record.directory(in: root)
        let manifestData=try Data(contentsOf:ExtensionPackageLoader.manifest(directory))
        try record.capabilityLedger?.validate(installed:manifestData)
        let manifest=try ExtensionManifest(data:manifestData)
        try manifest.validateNativeMessagingIdentity(record.packageIdentity)
        let ext=try await ExtensionPackageLoader.load(directory)
        if let current = records.first(where: { $0.id == record.id }), current.packageVersionID != record.packageVersionID {
            throw ExtensionValidationError.invalid("The extension package changed while loading.")
        }
        guard contexts[record.id] == nil else { return }
        try manifest.validateRequiredPermissions(recognized:Set(ext.requestedPermissions.map(\.rawValue)))
        guard ext.errors.isEmpty else{throw ExtensionValidationError.invalid(ext.errors.map(\.localizedDescription).joined(separator:"\n"))}
        let context=WKWebExtensionContext(for:ext);context.uniqueIdentifier=record.runtimeIdentifier
        if let base = record.resourceBaseURL ?? records.first(where: { $0.id == record.id })?.resourceBaseURL {
            guard ExtensionResourceOrigin.isValidBaseURL(base) else {
                throw ExtensionValidationError.invalid("The saved extension resource origin is invalid.")
            }
            guard var origin=URLComponents(url:base,resolvingAgainstBaseURL:false),let scheme=origin.scheme else {
                throw ExtensionValidationError.invalid("The saved extension resource origin cannot be parsed.")
            }
            origin.scheme=scheme.lowercased()
            guard let normalizedOrigin=origin.url else {
                throw ExtensionValidationError.invalid("The saved extension resource origin cannot be normalized.")
            }
            if origin.scheme=="moz-extension" {
                WKWebExtension.MatchPattern.registerCustomURLScheme("moz-extension")
            }
            context.baseURL = normalizedOrigin
        }
        context.hasAccessToPrivateData=false
        for permission in ext.requestedPermissions where record.permissions.contains(permission.rawValue) {context.setPermissionStatus(.grantedExplicitly,for:permission)}
        for pattern in ext.requestedPermissionMatchPatterns where record.hosts.contains(pattern.string) {context.setPermissionStatus(.grantedExplicitly,for:pattern)}
        if let state=record.permissionState {try state.apply(to:context)}
        try controller.load(context);contexts[record.id]=context;manifestAPIPermissions[record.id]=manifest.declaredAPIPermissions;contextErrors[record.id]=context.errors.map(\.localizedDescription);actionRevision += 1
        if let index = records.firstIndex(where: { $0.id == record.id }), records[index].resourceBaseURL == nil {
            records[index].resourceBaseURL = context.baseURL; save()
        }
        for window in manager?.windows ?? [] where !window.session.state.isPrivate {
            if let bridge=window.session.extensionWindow {context.didOpenWindow(bridge)}
        }
        reloadResourcePages(base:context.baseURL)
    }
    func chooseInstall(in session: BrowserSession) {
        guard !session.state.isPrivate,let window=session.dialogWindow else{return}
        let panel=NSOpenPanel();panel.canChooseFiles=true;panel.canChooseDirectories=true;panel.allowsMultipleSelection=false
        panel.message="Choose an unpacked WebExtension folder, ZIP, XPI, signed CRX3, or Safari Web Extension .appex bundle. Native Safari App Extensions and legacy CRX2 are not supported."
        panel.beginSheetModal(for:window){[weak self,weak session] response in
            guard response == .OK,let url=panel.url,let self,let session else{return}
            Task {await self.install(url,in:session)}
        }
    }
    func install(_ source: URL,in session: BrowserSession) async {
        error=nil
        guard !session.state.isPrivate else { error = "Extensions cannot be installed from a private window."; return }
        let access=source.startAccessingSecurityScopedResource();defer{if access{source.stopAccessingSecurityScopedResource()}}
        let id=UUID(),destination=root.appendingPathComponent(UUID().uuidString+".staging")
        do {
            let prepared = try preparePackage(source,at:destination)
            let identity = prepared.identity
            if let identity, records.contains(where: { $0.packageIdentity?.extensionID == identity.extensionID }) {
                throw ExtensionValidationError.invalid("This CRX3 developer identity is already installed. Use Update Signed Package on its existing entry.")
            }
            let manifestURL=try ExtensionPackageLoader.manifest(destination)
            let manifest=try ExtensionManifest(data:Data(contentsOf:manifestURL))
            try manifest.validateNativeMessagingIdentity(identity)
            let ext=try await ExtensionPackageLoader.load(destination)
            guard ext.errors.isEmpty else{throw ExtensionValidationError.invalid(ext.errors.map(\.localizedDescription).joined(separator:"\n"))}
            try manifest.validateRequiredPermissions(recognized:Set(ext.requestedPermissions.map(\.rawValue)))
            let permissions=ext.requestedPermissions.map(\.rawValue).sorted(),hosts=ext.requestedPermissionMatchPatterns.map(\.string).sorted()
            let provenance = identity.map { "Original CRX3 archive signature verified. Developer ID: \($0.extensionID). This is self-signed integrity, not Chrome Web Store approval. Normalized installed files are not the signed archive." } ?? "The package publisher signature has not been verified."
            let formatNote=try ExtensionPackageLayout.inspect(destination).isSafariBundle ? "\n\nSafari native handlers and containing-app integration are not supported." : ""
            let details="Version: \(ext.version ?? "Unknown")\n\nPermissions:\n\(permissions.joined(separator:"\n"))\n\nWebsite access:\n\(hosts.joined(separator:"\n"))\(formatNote)\n\n\(provenance) Install only if you trust its source. Private browsing access is disabled."
            let allowed=await withCheckedContinuation{continuation in session.confirm("Install \(ext.displayName ?? "extension")?",detail:details,yes:"Install"){continuation.resume(returning:$0)}}
            guard allowed else {try FileManager.default.removeItem(at:destination);return}
            if let identity, records.contains(where: { $0.packageIdentity?.extensionID == identity.extensionID }) {
                throw ExtensionValidationError.invalid("This CRX3 developer identity was installed while consent was pending.")
            }
            let final=root.appendingPathComponent(id.uuidString);try FileManager.default.moveItem(at:destination,to:final)
            var record=InstalledExtension(id:id,name:ext.displayName ?? "Extension",version:ext.version ?? "Unknown",enabled:true,permissions:permissions,hosts:hosts,packageIdentity:identity,contextIdentifier:identity?.extensionID,capabilityLedger:prepared.ledger)
            do {try await load(record);record.resourceBaseURL = contexts[id]?.baseURL;records.append(record);save()}
            catch {try? FileManager.default.removeItem(at:final);throw error}
        } catch {try? FileManager.default.removeItem(at:destination);self.error=error.localizedDescription}
    }
    @discardableResult
    func prepare(_ source: URL,at destination: URL) throws -> SignedExtensionIdentity? {
        try preparePackage(source,at:destination).identity
    }
    func preparePackage(_ source:URL,at destination:URL) throws -> (identity:SignedExtensionIdentity?,ledger:ExtensionCapabilityLedger) {
        var identity: SignedExtensionIdentity?
        let values=try source.resourceValues(forKeys:[.isDirectoryKey,.isSymbolicLinkKey,.isRegularFileKey])
        guard values.isSymbolicLink != true else{throw ExtensionValidationError.invalid("Symbolic-link packages are not accepted.")}
        if values.isDirectory==true {
            let enumerator=FileManager.default.enumerator(at:source,includingPropertiesForKeys:[.isSymbolicLinkKey,.fileSizeKey,.isRegularFileKey,.isDirectoryKey])
            var size=0,count=0
            while let file=enumerator?.nextObject() as? URL {
                let info=try file.resourceValues(forKeys:[.isSymbolicLinkKey,.fileSizeKey,.isRegularFileKey,.isDirectoryKey]);size+=info.fileSize ?? 0;count+=1
                guard info.isSymbolicLink != true,(info.isRegularFile==true || info.isDirectory==true),size<128*1024*1024,count<10_000 else{throw ExtensionValidationError.invalid("The package contains links, special files, or exceeds the resource limit.")}
            }
            if source.pathExtension.lowercased()=="appex" {
                guard try ExtensionPackageLayout.inspect(source).isSafariBundle else{throw ExtensionValidationError.invalid("Select an intact Safari Web Extension bundle.")}
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
            } else { archive = input }
            // Read from the same in-memory bytes we verified. Never give another
            // archive parser an opportunity to reinterpret names or filesystem metadata.
            try ExtensionArchive.extract(archive, to: destination)
            if !FileManager.default.fileExists(atPath:destination.appendingPathComponent("manifest.json").path) {
                let children=try FileManager.default.contentsOfDirectory(at:destination,includingPropertiesForKeys:[.isDirectoryKey]).filter{!$0.lastPathComponent.hasPrefix(".") && $0.lastPathComponent != "__MACOSX"}
                if children.count==1,let wrapper=children.first,FileManager.default.fileExists(atPath:wrapper.appendingPathComponent("manifest.json").path) {
                    for child in try FileManager.default.contentsOfDirectory(at:wrapper,includingPropertiesForKeys:nil) {try FileManager.default.moveItem(at:child,to:destination.appendingPathComponent(child.lastPathComponent))}
                    try FileManager.default.removeItem(at:wrapper)
                }
            }
        }
        let manifestURL=try ExtensionPackageLoader.manifest(destination)
        // A Safari bundle must stay byte-for-byte intact for resource validation.
        let original=try Data(contentsOf:manifestURL)
        let normalized:Data
        if try ExtensionPackageLayout.inspect(destination).isSafariBundle {normalized=original}
        else {normalized=try ExtensionCommandNormalization.normalize(original)}
        let ledger=try ExtensionCapabilityLedger(original:original,installed:normalized)
        if normalized != original {try normalized.write(to:manifestURL,options:.atomic)}
        return (identity,ledger)
    }
    func setEnabled(_ id: UUID,_ enabled: Bool) async {
        guard !busyIDs.contains(id), let record = records.first(where: { $0.id == id }) else { return }
        error=nil
        busyIDs.insert(id); defer { busyIDs.remove(id) }
        do {
            if enabled { try await load(record) }
            else if let context = contexts[id] { rememberPermissions(context); try unloadPreservingPageState(context); contexts[id] = nil;contextErrors[id]=nil }
            guard let index = records.firstIndex(where: { $0.id == id && $0.packageVersionID == record.packageVersionID }) else { return }
            records[index].enabled = enabled; save()
        } catch { self.error = error.localizedDescription }
    }
    func confirmRemoval(_ record: InstalledExtension,in session: BrowserSession) {
        session.confirm("Remove \(record.name)?",detail:"The package and extension settings will be removed. Some extension website data may remain; use Clear Website Data in Settings to remove it.",yes:"Remove") { [weak self] yes in
            if yes {Task {await self?.remove(record.id)}}
        }
    }
    func remove(_ id: UUID) async {
        guard !busyIDs.contains(id), let record = records.first(where: { $0.id == id }) else { return }
        error=nil
        busyIDs.insert(id); defer { busyIDs.remove(id) }
        do {
            if let context=contexts[id] {
                nativeMessaging.stop(context:context)
                try controller.unload(context)
            }
            contexts[id]=nil;contextErrors[id]=nil
            // Disabled extensions have no live context, but retain storage. Removal
            // must erase their data by the durable identity as well.
            // Session storage belongs to the unloaded context, not an on-disk
            // record. Querying it after unload produces WebKit storage errors.
            let persistentTypes=WKWebExtensionController.allExtensionDataTypes.subtracting([.session])
            let dataRecords=await controller.dataRecords(ofTypes:persistentTypes)
            let runtimeIdentifier = records.first { $0.id == id }?.runtimeIdentifier ?? id.uuidString
            let matching=dataRecords.filter{$0.uniqueIdentifier==runtimeIdentifier}
            await controller.removeData(ofTypes:persistentTypes,from:matching)
            let removalErrors=matching.flatMap(\.errors)
            guard removalErrors.isEmpty else {
                throw ExtensionValidationError.invalid("Extension data could not be removed: " + removalErrors.map(\.localizedDescription).joined(separator:"; "))
            }
            try FileManager.default.removeItem(at:record.directory(in: root));nativeMessaging.removeRegistrations(for:id);manifestAPIPermissions[id]=nil;records.removeAll{$0.id==id};save()
        } catch {self.error=error.localizedDescription}
    }
    func hasAction(_ id:UUID)->Bool {
        _=actionRevision
        guard let manifest=contexts[id]?.webExtension.manifest else{return false}
        return ["action","browser_action","page_action"].contains{manifest[$0] is [String:Any]}
    }
    func actionEnabled(_ id: UUID,in session: BrowserSession) -> Bool {
        _=actionRevision
        guard hasAction(id),!session.state.isPrivate else{return false}
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
    func performCommandFromLibrary(_ id:UUID,commandID:String,in session:BrowserSession) async -> Bool {
        guard !session.state.isPrivate,let context=contexts[id] else{return false}
        let tab=session.state.selectedTabID
        session.libraryPanel=nil
        for _ in 0..<40 {
            guard let window=session.window,contexts[id]===context,session.state.selectedTabID==tab else{return false}
            if window.attachedSheet==nil {
                guard window.isKeyWindow,let command=context.commands.first(where:{$0.id==commandID}) else{return false}
                context.performCommand(command)
                return true
            }
            try? await Task.sleep(for:.milliseconds(50))
        }
        error="Close the current dialog before running the extension command."
        return false
    }
    func perform(_ id: UUID,in session: BrowserSession) {
        guard actionEnabled(id,in:session),let context=contexts[id],let tab=session.state.selectedTabID,
              isCurrentPermissionPrompt(context:context,session:session,tab:session.bridge(tab)) else{return}
        context.userGesturePerformed(in:session.bridge(tab));context.performAction(for:session.bridge(tab))
    }
    @discardableResult func setCurrentSite(_ id:UUID,in session:BrowserSession,allow:Bool)->Bool {
        guard !session.state.isPrivate,manager?.windows.contains(where:{$0.session===session})==true,
              let context=contexts[id],let url=session.current?.webView.url,
              ["http","https"].contains(url.scheme?.lowercased() ?? "") else{return false}
        context.setPermissionStatus(allow ? .grantedExplicitly : .deniedExplicitly,for:url)
        rememberPermissions(context)
        return true
    }
    /// Current WebKit background fetches can outlive a site denial. Make the
    /// conservative UI action explicit; raw policy semantics remain tested apart.
    @discardableResult func denyCurrentSiteAndDisable(_ id:UUID,in session:BrowserSession) async->Bool {
        guard !busyIDs.contains(id),setCurrentSite(id,in:session,allow:false) else{return false}
        await setEnabled(id,false)
        return contexts[id]==nil && records.first(where:{$0.id==id})?.enabled==false
    }
}
