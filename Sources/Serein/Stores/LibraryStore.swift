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
    private(set) var preservationNotice:String?
    let root: URL
    @ObservationIgnored private var bookmarksAvailable=true
    @ObservationIgnored private var historyAvailable=true
    init(root: URL) {
        self.root=root
        do {try PrivateFileStore.prepareDirectory(root)}
        catch {bookmarksAvailable=false;historyAvailable=false;self.error="Could not open browsing library: \(error.localizedDescription)";preservationNotice=self.error;return}
        var failures:[String]=[]
        for isHistory in [false,true] {
            let name=isHistory ? "history.json" : "bookmarks.json"
            do {
                let original:[PageRecord]=try read(name) ?? []
                let safe=original.compactMap{Self.sanitized($0,history:isHistory)}
                if safe != original {try commit(safe,name:name)}
                if isHistory {history=safe} else {bookmarks=safe}
            } catch {
                if isHistory {historyAvailable=false} else {bookmarksAvailable=false}
                failures.append("Could not restore \(name). The original file is preserved and edits are disabled: \(error.localizedDescription)")
            }
        }
        if !failures.isEmpty {error=failures.joined(separator:"\n");preservationNotice=error}
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
        let values=try url.resourceValues(forKeys:[.fileSizeKey,.isRegularFileKey,.isSymbolicLinkKey])
        guard values.isRegularFile==true,values.isSymbolicLink != true,values.fileSize.map({$0<=16*1024*1024})==true else {
            throw BookmarkEditError.invalid("Library storage must be a regular file no larger than 16 MiB.")
        }
        let handle=try FileHandle(forReadingFrom:url);defer{try? handle.close()}
        let data=try handle.read(upToCount:16*1024*1024+1) ?? Data()
        guard data.count<=16*1024*1024 else{throw BookmarkEditError.invalid("Library file exceeds the 16 MiB limit.")}
        return try JSONDecoder().decode(T.self,from:data)
    }
    private func commit(_ records:[PageRecord],name:String) throws {
        let data=try JSONEncoder().encode(records)
        guard data.count<=16*1024*1024 else{throw BookmarkEditError.invalid("The library update exceeds the 16 MiB limit.")}
        try PrivateFileStore.write(data,to:root.appendingPathComponent(name))
    }
    func visit(title: String, url: String, isPrivate: Bool) {
        guard !isPrivate,historyAvailable,let safeURL=StoredPageURL.webHistoryURL(url) else{return}
        var record=history.first{$0.url==safeURL} ?? PageRecord(title:"",url:safeURL)
        record.title=title==url ? safeURL : title;record.date=Date()
        let proposed=Array(([record]+history.filter{$0.url != safeURL}).prefix(3000))
        do {
            try commit(proposed,name:"history.json")
            history=proposed
        } catch {self.error="Could not save browsing history: \(error.localizedDescription)"}
    }
    func bookmark(title: String, url: String) {
        guard let safeURL=StoredPageURL.removingCredentials(url),!bookmarks.contains(where:{$0.url==safeURL}) else{return}
        do {try saveBookmark(original:nil,title:title,url:url)}
        catch {self.error=error.localizedDescription}
    }
    /// Commit to disk before publishing the new list. An editor must still own
    /// the exact record it opened; another window's edit/removal wins conflicts.
    func saveBookmark(original:PageRecord?,title:String,url:String) throws {
        guard bookmarksAvailable else{throw BookmarkEditError.invalid("Bookmarks could not be restored. The original file is preserved; repair or back it up before editing.")}
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
        try commit(proposed,name:"bookmarks.json")
        bookmarks=proposed
    }
    func removeBookmark(_ id: UUID) {
        guard bookmarksAvailable else{return}
        let proposed=bookmarks.filter{$0.id != id}
        do {try commit(proposed,name:"bookmarks.json");bookmarks=proposed}
        catch {self.error="Could not remove bookmark: \(error.localizedDescription)"}
    }
    func clearHistory() {
        guard historyAvailable else{return}
        do {
            try commit([],name:"history.json")
            history=[];error=nil
        } catch {self.error="Could not clear browsing history: \(error.localizedDescription)"}
    }
    func suggestions(_ query: String) -> [PageRecord] {
        guard !query.isEmpty else{return Array(bookmarks.prefix(8))}
        var seen=Set<String>()
        return Array((bookmarks+history).filter{($0.title.localizedCaseInsensitiveContains(query) || $0.url.localizedCaseInsensitiveContains(query)) && seen.insert($0.url).inserted}.prefix(8))
    }
}
