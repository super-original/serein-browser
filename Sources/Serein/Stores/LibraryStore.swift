import Foundation
import Observation
import SereinCore

struct PageRecord: Identifiable, Codable, Equatable {
    var id=UUID()
    var title: String
    var url: String
    var date=Date()
}
enum BookmarkEditError:LocalizedError {
    case invalid(String)
    var errorDescription:String? {if case .invalid(let message)=self {return message};return nil}
}
@MainActor @Observable final class LibraryStore {
    var bookmarks: [PageRecord] = []
    var history: [PageRecord] = []
    var error: String?
    let root: URL
    init(root: URL) {
        self.root=root
        do {
            try PrivateFileStore.prepareDirectory(root)
            bookmarks=try read("bookmarks.json") ?? []
            history=try read("history.json") ?? []
            let oldBookmarks = bookmarks, oldHistory = history
            bookmarks = bookmarks.compactMap { Self.sanitized($0, history: false) }
            history = history.compactMap { Self.sanitized($0, history: true) }
            if bookmarks != oldBookmarks { write(bookmarks, name: "bookmarks.json") }
            if history != oldHistory { write(history, name: "history.json") }
        } catch {self.error="Could not restore browsing library: \(error.localizedDescription)"}
    }
    private static func sanitized(_ record: PageRecord, history: Bool) -> PageRecord? {
        guard let safeURL = history ? StoredPageURL.webHistoryURL(record.url) : StoredPageURL.removingCredentials(record.url) else { return nil }
        var result = record; result.url = safeURL
        if record.title == record.url { result.title = safeURL }
        return result
    }
    func read<T: Decodable>(_ name: String) throws -> T? {
        let url=root.appendingPathComponent(name)
        guard FileManager.default.fileExists(atPath:url.path) else{return nil}
        return try JSONDecoder().decode(T.self,from:Data(contentsOf:url))
    }
    func write<T: Encodable>(_ object: T, name: String) {
        do {try PrivateFileStore.write(JSONEncoder().encode(object),to:root.appendingPathComponent(name))}
        catch {self.error="Could not save \(name): \(error.localizedDescription)"}
    }
    func visit(title: String, url: String, isPrivate: Bool) {
        guard !isPrivate, let safeURL = StoredPageURL.webHistoryURL(url) else { return }
        history.removeAll{$0.url==safeURL};history.insert(PageRecord(title:title == url ? safeURL : title,url:safeURL),at:0)
        history=Array(history.prefix(3000));write(history,name:"history.json")
    }
    func bookmark(title: String, url: String) {
        guard let safeURL=StoredPageURL.removingCredentials(url),!bookmarks.contains(where:{$0.url==safeURL}) else{return}
        do {try saveBookmark(original:nil,title:title,url:url)}
        catch {self.error=error.localizedDescription}
    }
    /// Commit to disk before publishing the new list. An editor must still own
    /// the exact record it opened; another window's edit/removal wins conflicts.
    func saveBookmark(original:PageRecord?,title:String,url:String) throws {
        let entered=url.trimmingCharacters(in:.whitespacesAndNewlines)
        guard let safeURL=StoredPageURL.removingCredentials(entered),let parsed=URL(string:safeURL),
              !["http","https"].contains(parsed.scheme?.lowercased() ?? "") || parsed.host?.isEmpty==false else {
            throw BookmarkEditError.invalid("Enter a complete address, including its scheme, such as https://example.com.")
        }
        var proposed=bookmarks
        let index:Int?
        if let original {
            guard let current=bookmarks.firstIndex(where:{$0.id==original.id}),bookmarks[current]==original else {
                throw BookmarkEditError.invalid("This bookmark changed or was removed in another window. Close this editor and reopen it.")
            }
            index=current
        } else {index=nil}
        guard !bookmarks.contains(where:{$0.url==safeURL && $0.id != original?.id}) else {
            throw BookmarkEditError.invalid("A bookmark with this address already exists.")
        }
        let name=title.trimmingCharacters(in:.whitespacesAndNewlines)
        var record=original ?? PageRecord(title:"",url:safeURL)
        record.title=name.isEmpty || name==entered ? safeURL : name;record.url=safeURL
        if let index {proposed[index]=record} else {proposed.append(record)}
        try PrivateFileStore.write(JSONEncoder().encode(proposed),to:root.appendingPathComponent("bookmarks.json"))
        bookmarks=proposed
    }
    func removeBookmark(_ id: UUID) {
        let proposed=bookmarks.filter{$0.id != id}
        do {try PrivateFileStore.write(JSONEncoder().encode(proposed),to:root.appendingPathComponent("bookmarks.json"));bookmarks=proposed}
        catch {self.error="Could not remove bookmark: \(error.localizedDescription)"}
    }
    func clearHistory() {
        do {
            try PrivateFileStore.write(JSONEncoder().encode([PageRecord]()),to:root.appendingPathComponent("history.json"))
            history=[];error=nil
        } catch {self.error="Could not clear browsing history: \(error.localizedDescription)"}
    }
    func suggestions(_ query: String) -> [PageRecord] {
        guard !query.isEmpty else{return Array(bookmarks.prefix(8))}
        var seen=Set<String>()
        return Array((bookmarks+history).filter{($0.title.localizedCaseInsensitiveContains(query) || $0.url.localizedCaseInsensitiveContains(query)) && seen.insert($0.url).inserted}.prefix(8))
    }
}
