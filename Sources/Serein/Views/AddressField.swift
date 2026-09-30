import SwiftUI

struct NavigationButtons: View {
    let session: BrowserSession
    var body: some View {
        Group {
            Button("Back",systemImage:"arrow.left"){session.current?.goBack()}.disabled(!(session.current?.canGoBack ?? false))
            Button("Forward",systemImage:"arrow.right"){session.current?.goForward()}.disabled(!(session.current?.canGoForward ?? false))
            Button(session.current?.isLoading==true ? "Stop" : "Reload",systemImage:session.current?.isLoading==true ? "xmark" : "arrow.clockwise") {if session.current?.isLoading==true{session.current?.webView.stopLoading()}else{session.current?.reload()}}
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
    @State private var selectedSuggestion: UUID?
    @State private var suggestionsDismissed=false
    @State private var focusPageAfterSubmit=false
    private var suggestions:[PageRecord] {session.manager?.library.suggestions(session.address) ?? []}
    private func moveSuggestion(_ direction:Int) -> KeyPress.Result {
        guard focused,!suggestions.isEmpty else{return .ignored}
        suggestionsDismissed=false
        let index=selectedSuggestion.flatMap{id in suggestions.firstIndex{$0.id==id}}
        if direction>0 {selectedSuggestion=suggestions[min((index ?? -1)+1,suggestions.count-1)].id}
        else if let index,index>0 {selectedSuggestion=suggestions[index-1].id}
        else {selectedSuggestion=nil}
        return .handled
    }
    private func submit() {
        let target=selectedSuggestion.flatMap{id in suggestions.first{$0.id==id}?.url} ?? session.address
        session.navigate(target);focusPageAfterSubmit=true;focused=false;selectedSuggestion=nil
    }
    var body: some View {
        TextField("Search or enter address",text:$session.address)
            .textFieldStyle(.bordered).controlSize(.large).font(.system(size:13)).frame(height:36)
            .focused($focused).accessibilityIdentifier("address-field")
            .onSubmit{submit()}
            .onKeyPress(.downArrow){moveSuggestion(1)}
            .onKeyPress(.upArrow){moveSuggestion(-1)}
            .onChange(of:session.address){_,_ in selectedSuggestion=nil;suggestionsDismissed=false}
            .onChange(of:session.addressFocused){_,value in focused=value}
            .onChange(of:focused){_,value in
                session.addressFocused=value;selectedSuggestion=nil;suggestionsDismissed=false
                if !value,focusPageAfterSubmit {focusPageAfterSubmit=false;session.focusContent(ifSelected:session.state.selectedTabID)}
            }
            .onExitCommand{
                if !suggestionsDismissed,!session.address.isEmpty,!suggestions.isEmpty {suggestionsDismissed=true;selectedSuggestion=nil}
                else {focused=false;session.addressFocused=false}
            }
            .popover(isPresented:Binding(get:{focused && !suggestionsDismissed && !session.address.isEmpty && !suggestions.isEmpty},set:{if !$0 {suggestionsDismissed=true;selectedSuggestion=nil}}),arrowEdge:.trailing) {
                VStack(alignment:.leading,spacing:2) {
                    ForEach(suggestions){record in
                        Button {session.navigate(record.url);focusPageAfterSubmit=true;focused=false} label:{VStack(alignment:.leading,spacing:3){Text(record.title).lineLimit(1);Text(record.url).font(.caption).foregroundStyle(.secondary).lineLimit(1)}.frame(maxWidth:.infinity,alignment:.leading).padding(8)}.buttonStyle(.plain)
                            .background(selectedSuggestion==record.id ? Color.accentColor.opacity(0.18) : Color.clear,in:RoundedRectangle(cornerRadius:6))
                            .accessibilityAddTraits(selectedSuggestion==record.id ? .isSelected : [])
                    }
                }.padding(6).frame(width:360)
            }
    }
}
