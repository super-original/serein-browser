import AppKit
import WebKit
import SereinCore

extension ExtensionHost {
    func chooseUpdate(_ id: UUID, in session: BrowserSession) {
        guard !session.state.isPrivate, !busyIDs.contains(id), let window = session.dialogWindow else { return }
        let panel = NSOpenPanel(); panel.canChooseDirectories = false; panel.allowsMultipleSelection = false
        panel.message = "Choose a newer CRX3 signed by this extension's developer. Automatic store updates and unsigned-package updates are not available."
        panel.beginSheetModal(for: window) { [weak self, weak session] response in
            guard response == .OK, let source = panel.url, let self, let session else { return }
            Task { await self.update(id, from: source, in: session) }
        }
    }
    @discardableResult
    func update(_ id: UUID, from source: URL, in session: BrowserSession) async -> Bool {
        guard !session.state.isPrivate, !busyIDs.contains(id),
              let original = records.first(where: { $0.id == id }), let previousIdentity = original.packageIdentity else {
            error = "Only an installed signed CRX3 can be updated from a normal window."; return false
        }
        busyIDs.insert(id); defer { busyIDs.remove(id) }
        error = nil
        let access = source.startAccessingSecurityScopedResource()
        defer { if access { source.stopAccessingSecurityScopedResource() } }
        let candidate = root.appendingPathComponent(UUID().uuidString + ".staging")
        defer { if FileManager.default.fileExists(atPath: candidate.path) { try? FileManager.default.removeItem(at: candidate) } }
        do {
            guard let identity = try prepare(source, at: candidate) else { throw ExtensionValidationError.invalid("Updates require a verified CRX3 package.") }
            let manifest = try ExtensionManifest(data: Data(contentsOf: candidate.appendingPathComponent("manifest.json")))
            try manifest.validateNativeMessagingIdentity(identity)
            try SignedExtensionUpdate.validate(previous: previousIdentity, version: original.version, candidate: identity, candidateVersion: manifest.version)
            let ext = try await WKWebExtension(resourceBaseURL: candidate)
            guard ext.errors.isEmpty else { throw ExtensionValidationError.invalid(ext.errors.map(\.localizedDescription).joined(separator: "\n")) }
            try manifest.validateRequiredPermissions(recognized: Set(ext.requestedPermissions.map(\.rawValue)))
            let permissions = ext.requestedPermissions.map(\.rawValue).sorted(), hosts = ext.requestedPermissionMatchPatterns.map(\.string).sorted()
            let added = Set(permissions).subtracting(original.permissions).sorted() + Set(hosts).subtracting(original.hosts).sorted()
            let detail = "Version \(original.version) → \(manifest.version)\n\nNew requests:\n\(added.isEmpty ? "None" : added.joined(separator: "\n"))\n\nAll requested permissions and sites:\n\((permissions + hosts).joined(separator: "\n"))\n\nThe original archive is signed by the same developer key. Explicit denials are retained. Revoked permissions that were already required stay revoked. Newly required permissions are reviewed above; optional access may need approval again when scopes change. Extension data and identity are preserved. Open extension pages will reload. Empty reserved command descriptions may be normalized in the installed copy; the original archive stays unchanged. Private access stays disabled."
            let allowed = await withCheckedContinuation { continuation in
                session.confirm("Update \(original.name)?", detail: detail, yes: "Update", identifier:"extension-update-\(id)") { continuation.resume(returning: $0) }
            }
            guard allowed else { return false }
            guard let index = records.firstIndex(where: { $0.id == id }),
                  records[index].packageIdentity == previousIdentity, records[index].version == original.version else {
                throw ExtensionValidationError.invalid("The installed package changed while update consent was pending.")
            }
            if let context = contexts[id] { rememberPermissions(context) }
            let previous = records[index]
            let state = previous.permissionState ?? ExtensionPermissionState(
                granted: Dictionary(uniqueKeysWithValues: previous.permissions.map { ($0, Date.distantFuture) }), denied: [:],
                grantedHosts: Dictionary(uniqueKeysWithValues: previous.hosts.map { ($0, Date.distantFuture) }), deniedHosts: [:])
            var updated = previous
            updated.name = ext.displayName ?? manifest.name; updated.version = manifest.version
            updated.permissions = permissions; updated.hosts = hosts; updated.packageIdentity = identity
            updated.packageVersionID = UUID()
            updated.permissionState = try state.updating(from: previous, to: ext)
            var proposed = records; proposed[index] = updated
            let registry = try JSONEncoder().encode(proposed)
            if let context = contexts[id] { try unloadPreservingPageState(context); contexts[id] = nil }
            do {
                try ExtensionPackageStorage.commitPrepared(candidate, root: root, versionID: updated.packageVersionID!, registry: registry)
            } catch {
                var detail = error.localizedDescription
                if previous.enabled {
                    do { try await load(previous) }
                    catch { detail += " Restoring the previous running extension also failed: \(error.localizedDescription)" }
                }
                throw ExtensionValidationError.invalid(detail)
            }
            records = proposed
            if updated.enabled {
                do { try await load(updated) }
                catch {
                    if let current = records.firstIndex(where: { $0.id == id }) { records[current].enabled = false; save() }
                    self.error = "The verified update was installed but could not activate; it is disabled. Previous package files were retained. \(error.localizedDescription)"
                    return false
                }
            }
            actionRevision += 1
            do { try FileManager.default.removeItem(at: previous.directory(in: root)) }
            catch { self.error = "Update installed; previous package cleanup failed: \(error.localizedDescription)" }
            return true
        } catch { self.error = error.localizedDescription; return false }
    }
    func unloadPreservingPageState(_ context:WKWebExtensionContext) throws {
        let runtimes=(manager?.windows ?? []).filter{!$0.session.state.isPrivate}.flatMap{Array($0.session.runtimes.values)}.filter{$0.captureExtensionReloadState(for:context)}
        nativeMessaging.stop(context:context)
        do {try controller.unload(context)}
        catch {for runtime in runtimes {runtime.reload()};throw error}
    }
    func reloadResourcePages(base: URL) {
        for window in manager?.windows ?? [] where !window.session.state.isPrivate {
            let session = window.session
            for tab in session.state.tabs {
                guard let url = URL(string: tab.url), url.scheme == base.scheme, url.host == base.host,
                      let runtime = session.runtimes[tab.id], runtime.loadedWebView != nil || runtime.hasPendingExtensionReload else { continue }
                runtime.reload()
            }
        }
    }

}
