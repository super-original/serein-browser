import Foundation
import Observation
import SereinCore

struct PageRecord: Identifiable, Codable {
    var id=UUID()
    var title: String
    var url: String
    var date=Date()
}
@MainActor @Observable final class LibraryStore {
    var bookmarks: [PageRecord] = []
    var history: [PageRecord] = []
    var error: String?
    let root: URL
    init(root: URL) {
        self.root=root
        do {
            try FileManager.default.createDirectory(at:root,withIntermediateDirectories:true)
            bookmarks=try read("bookmarks.json") ?? []
            history=try read("history.json") ?? []
        } catch {self.error="Could not restore browsing library: \(error.localizedDescription)"}
    }
    func read<T: Decodable>(_ name: String) throws -> T? {
        let url=root.appendingPathComponent(name)
        guard FileManager.default.fileExists(atPath:url.path) else{return nil}
        return try JSONDecoder().decode(T.self,from:Data(contentsOf:url))
    }
    func write<T: Encodable>(_ object: T, name: String) {
        do {try JSONEncoder().encode(object).write(to:root.appendingPathComponent(name),options:.atomic)}
        catch {self.error="Could not save \(name): \(error.localizedDescription)"}
    }
    func visit(title: String, url: String, isPrivate: Bool) {
        guard !isPrivate,url.hasPrefix("http") else{return}
        history.removeAll{$0.url==url};history.insert(PageRecord(title:title,url:url),at:0)
        history=Array(history.prefix(3000));write(history,name:"history.json")
    }
    func bookmark(title: String, url: String) {
        guard !bookmarks.contains(where:{$0.url==url}),URL(string:url) != nil else{return}
        bookmarks.append(PageRecord(title:title,url:url));write(bookmarks,name:"bookmarks.json")
    }
    func removeBookmark(_ id: UUID) {bookmarks.removeAll{$0.id==id};write(bookmarks,name:"bookmarks.json")}
    func clearHistory() {history=[];write(history,name:"history.json")}
    func suggestions(_ query: String) -> [PageRecord] {
        guard !query.isEmpty else{return Array(bookmarks.prefix(8))}
        var seen=Set<String>()
        return Array((bookmarks+history).filter{($0.title.localizedCaseInsensitiveContains(query) || $0.url.localizedCaseInsensitiveContains(query)) && seen.insert($0.url).inserted}.prefix(8))
    }
}
