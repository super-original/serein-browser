import SwiftUI
import SereinCore

struct BookmarkEditorRequest:Identifiable {
    let id=UUID()
    let original:PageRecord?
    let title:String
    let url:String
    init(original:PageRecord?=nil,title:String,url:String) {self.original=original;self.title=title;self.url=url}
}
struct BookmarkEditorView:View {
    let store:LibraryStore
    let request:BookmarkEditorRequest
    @State private var title:String
    @State private var url:String
    @State private var error:String?
    @FocusState private var titleFocused:Bool
    @Environment(\.dismiss) private var dismiss
    init(store:LibraryStore,request:BookmarkEditorRequest) {
        self.store=store;self.request=request
        _title=State(initialValue:request.title);_url=State(initialValue:request.url)
    }
    var body:some View {
        VStack(alignment:.leading,spacing:16) {
            Text(request.original==nil ? "Add Bookmark" : "Edit Bookmark").font(.title2.bold())
            VStack(alignment:.leading,spacing:6) {
                Text("Name").font(.subheadline)
                TextField("Name",text:$title).textFieldStyle(.bordered).focused($titleFocused)
                    .accessibilityIdentifier("bookmark-title").onSubmit{save()}
            }
            VStack(alignment:.leading,spacing:6) {
                Text("Address").font(.subheadline)
                TextField("Address",text:$url).textFieldStyle(.bordered)
                    .accessibilityIdentifier("bookmark-url").onSubmit{save()}
            }
            if let error {Text(error).font(.callout).foregroundStyle(.red).textSelection(.enabled)}
            HStack {
                Button("Cancel"){dismiss()}.keyboardShortcut(.cancelAction)
                Spacer()
                Button("Save"){save()}.keyboardShortcut(.defaultAction)
            }
        }.padding(24).frame(width:440).onAppear{titleFocused=true}
    }
    private func save() {
        do {try store.saveBookmark(original:request.original,title:title,url:url);dismiss()}
        catch {self.error=error.localizedDescription}
    }
}
