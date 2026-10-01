import Foundation
import SereinCore

@MainActor enum LibraryVerification {
    static func run(root: URL) -> [RuntimeVerification.Result] {
        var results: [RuntimeVerification.Result] = []
        func check(_ name: String, _ passed: Bool, _ detail: String = "") {
            results.append(.init(name: name, passed: passed, detail: detail))
        }
        let directory = root.appendingPathComponent("library-persistence-probe")
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            let raw = "https://fixture-user:fixture-password@example.test/path?q=value#anchor"
            let safe = "https://example.test/path?q=value#anchor"
            let legacy = [PageRecord(title: raw, url: raw)]
            for name in ["bookmarks.json", "history.json"] {
                try JSONEncoder().encode(legacy).write(to: directory.appendingPathComponent(name))
            }
            let store = LibraryStore(root: directory)
            check("library-legacy-credentials-sanitized", store.bookmarks.first?.url == safe && store.history.first?.url == safe && store.history.first?.title == safe)
            let disk = try ["bookmarks.json", "history.json"].map { try String(contentsOf: directory.appendingPathComponent($0), encoding: .utf8) }.joined()
            check("library-legacy-files-rewritten", !disk.contains("fixture-user") && !disk.contains("fixture-password"), store.error ?? "")
            store.visit(title: "Updated title", url: raw, isPrivate: false)
            store.bookmark(title: "Duplicate", url: raw)
            check("library-credential-free-deduplication", store.history.count == 1 && store.bookmarks.count == 1 && store.history[0].url == safe)
            store.visit(title: "Private", url: "https://example.test/private", isPrivate: true)
            store.visit(title: "Non-web", url: "http-unrelated://example.test/", isPrivate: false)
            check("library-private-and-nonweb-excluded", store.history.count == 1)
            let restored = LibraryStore(root: directory)
            check("library-sanitized-persistence", restored.history.first?.url == safe && restored.history.first?.title == "Updated title" && restored.bookmarks.first?.url == safe)
            let original=store.bookmarks[0]
            try store.saveBookmark(original:original,title:"  Edited bookmark  ",url:"https://edit-user:edit-password@example.test/new")
            let edited=store.bookmarks[0]
            let editedRestore=LibraryStore(root:directory)
            check("bookmark-edit-persists-identity-and-redacts",edited.id==original.id && edited.date==original.date && edited.title=="Edited bookmark" && edited.url=="https://example.test/new" && editedRestore.bookmarks==store.bookmarks)
            func rejected(_ action:() throws -> Void)->Bool {do {try action();return false} catch {return true}}
            let stale=rejected{try store.saveBookmark(original:original,title:"Stale",url:safe)}
            check("bookmark-stale-edit-rejected",stale && store.bookmarks[0]==edited)
            store.bookmark(title:"Other",url:"https://example.test/other")
            let before=store.bookmarks
            let duplicate=rejected{try store.saveBookmark(original:edited,title:"Duplicate",url:"https://example.test/other")}
            let invalid=rejected{try store.saveBookmark(original:edited,title:"Invalid",url:"http://")}
            check("bookmark-invalid-and-duplicate-atomic",duplicate && invalid && store.bookmarks==before)
            let file=directory.appendingPathComponent("bookmarks.json"),saved=try Data(contentsOf:file)
            try FileManager.default.removeItem(at:file)
            try FileManager.default.createDirectory(at:file,withIntermediateDirectories:false)
            let writeFailed=rejected{try store.saveBookmark(original:edited,title:"Cannot save",url:edited.url)}
            check("bookmark-failed-write-does-not-publish",writeFailed && store.bookmarks==before)
            try FileManager.default.removeItem(at:file);try saved.write(to:file,options:.atomic)
            store.bookmark(title:"https://name:secret@example.test/last",url:"https://name:secret@example.test/last")
            check("bookmark-title-url-remains-redacted",store.bookmarks.last?.title=="https://example.test/last" && store.bookmarks.last?.url=="https://example.test/last")

        } catch { check("library-persistence-probe", false, error.localizedDescription) }
        return results
    }
}
