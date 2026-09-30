import Foundation
import Observation
import SereinCore

@MainActor @Observable final class SitePermissionStore {
    private(set) var policy = SitePermissionPolicy()
    private(set) var error: String?
    private let file: URL?

    /// Private windows receive distinct stores with no persistence destination.
    init(file: URL? = nil) {
        self.file = file
        guard let file, FileManager.default.fileExists(atPath: file.path) else { return }
        do { policy = try JSONDecoder().decode(SitePermissionPolicy.self, from: Data(contentsOf: file)) }
        catch { self.error = "Saved site permissions could not be read. Requests will ask again: \(error.localizedDescription)" }
    }

    func set(_ decision: SitePermissionDecision, for keys: [SitePermissionKey]) {
        for key in keys { policy.set(decision, for: key) }
        save()
    }

    func reset() { policy.reset(); save() }

    private func save() {
        guard let file else { return }
        do {
            try FileManager.default.createDirectory(at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
            try JSONEncoder().encode(policy).write(to: file, options: .atomic)
            error = nil
        } catch { self.error = "Site permissions could not be saved: \(error.localizedDescription)" }
    }
}
