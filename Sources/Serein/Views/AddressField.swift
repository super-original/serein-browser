import SwiftUI

struct NavigationButtons: View {
    let session: BrowserSession
    var body: some View {
        Group {
            Button("Back",systemImage:"arrow.left"){session.current?.webView.goBack()}.disabled(!(session.current?.canGoBack ?? false))
            Button("Forward",systemImage:"arrow.right"){session.current?.webView.goForward()}.disabled(!(session.current?.canGoForward ?? false))
            Button(session.current?.isLoading==true ? "Stop" : "Reload",systemImage:session.current?.isLoading==true ? "xmark" : "arrow.clockwise") {if session.current?.isLoading==true{session.current?.webView.stopLoading()}else{session.current?.webView.reload()}}
        }.labelStyle(.iconOnly).buttonStyle(.plain).frame(width:24,height:28)
    }
}
struct NavigationBar: View {
    let session: BrowserSession
    var body: some View {HStack(spacing:8){Button("Expand Sidebar",systemImage:"sidebar.left"){session.state.sidebar = .expanded}.labelStyle(.iconOnly).buttonStyle(.plain);NavigationButtons(session:session);AddressField(session:session)}}
}
struct AddressField: View {
    @Bindable var session: BrowserSession
    @FocusState private var focused: Bool
    var body: some View {
        TextField("Search or enter address",text:$session.address)
            .textFieldStyle(.bordered).controlSize(.large).font(.system(size:13)).frame(height:36)
            .focused($focused).accessibilityIdentifier("address-field")
            .onSubmit{session.navigate(session.address);focused=false}
            .onChange(of:session.addressFocused){_,value in focused=value}
            .onChange(of:focused){_,value in session.addressFocused=value}
            .onExitCommand{focused=false;session.addressFocused=false}
            .popover(isPresented:Binding(get:{focused && !session.address.isEmpty && !(session.manager?.library.suggestions(session.address).isEmpty ?? true)},set:{_ in}),arrowEdge:.trailing) {
                VStack(alignment:.leading,spacing:2) {
                    ForEach(session.manager?.library.suggestions(session.address) ?? []){record in
                        Button {session.navigate(record.url);focused=false} label:{VStack(alignment:.leading,spacing:3){Text(record.title).lineLimit(1);Text(record.url).font(.caption).foregroundStyle(.secondary).lineLimit(1)}.frame(maxWidth:.infinity,alignment:.leading).padding(8)}.buttonStyle(.plain)
                    }
                }.padding(6).frame(width:360)
            }
    }
}
