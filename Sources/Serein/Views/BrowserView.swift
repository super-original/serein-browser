import SwiftUI
import WebKit
import SereinCore

struct BrowserView: View {
    @Bindable var session: BrowserSession
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @AppStorage("appearance") private var appearance="system"
    @State private var resizeStart: Double?
    @State private var compactHideTask: Task<Void,Never>?
    var body: some View {
        ZStack(alignment:.leading) {
            HStack(spacing:0) {
                if session.state.sidebar != .compact {
                    SidebarView(session:session)
                        .frame(width:session.state.sidebar == .collapsed ? 48 : session.state.sidebarWidth)
                    if session.state.sidebar == .expanded {
                        Color.clear.frame(width:6).contentShape(Rectangle()).gesture(DragGesture().onChanged { value in
                            if resizeStart==nil {resizeStart=session.state.sidebarWidth}
                            session.state.sidebarWidth=min(500,max(180,(resizeStart ?? 230)+value.translation.width))
                        }.onEnded{_ in resizeStart=nil})
                    }
                }
                VStack(spacing:6) {
                    if session.state.sidebar == .collapsed {NavigationBar(session:session).padding(.leading,48).frame(height:38)}
                    if session.findVisible {FindBar(session:session)}
                    if let second=session.state.secondaryTabID,let selected=session.state.selectedTabID {
                        HSplitView {PagePane(session:session,id:selected).frame(minWidth:230);PagePane(session:session,id:second).frame(minWidth:230)}
                    } else if let selected=session.state.selectedTabID {PagePane(session:session,id:selected)}
                }
                .padding(.vertical,8).padding(.trailing,8)
                .padding(.leading,session.state.sidebar == .compact ? 8 : 0)
            }
            if session.state.sidebar == .compact {
                Color.clear.frame(width:8).contentShape(Rectangle()).onHover{inside in if inside{session.compactRevealed=true}}
                if session.compactRevealed {
                    SidebarView(session:session).frame(width:session.state.sidebarWidth).padding(6)
                        .onHover {inside in
                            compactHideTask?.cancel()
                            guard !inside,!session.addressFocused,session.libraryPanel==nil else{return}
                            compactHideTask=Task {try? await Task.sleep(for:.milliseconds(150));if !Task.isCancelled,!session.addressFocused{session.compactRevealed=false}}
                        }
                        .transition(.move(edge:.leading))
                }
            }
        }
        .animation(reduceMotion ? nil : .easeInOut(duration:0.16),value:session.state.sidebar)
        .animation(reduceMotion ? nil : .easeInOut(duration:0.16),value:session.compactRevealed)
        .ignoresSafeArea()
        .preferredColorScheme(appearance=="dark" ? .dark : appearance=="light" ? .light : nil)
        .sheet(item:$session.libraryPanel){panel in LibraryPanelView(session:session,panel:panel)}
        .alert("Serein",isPresented:Binding(get:{session.error != nil},set:{if !$0{session.error=nil}})){Button("OK"){session.error=nil}} message:{Text(session.error ?? "")}
    }
}
private struct PagePane: View {
    let session: BrowserSession
    let id: UUID
    var body: some View {
        let runtime=session.runtime(id)
        ZStack {
            WebContentView(runtime:runtime).id(id)
            if session.state.tabs.first(where:{$0.id==id})?.url=="about:blank" {
                VStack(spacing:12) {
                    Image(systemName:session.state.isPrivate ? "hand.raised" : "sparkle").font(.system(size:32,weight:.light))
                    Text(session.state.isPrivate ? "Private Browsing" : "New Tab").font(.title2)
                    Text(session.state.isPrivate ? "History and tabs from this window won’t be saved." : "⌘L to search or enter an address").foregroundStyle(.secondary)
                }.frame(maxWidth:.infinity,maxHeight:.infinity).background(Color(nsColor:.textBackgroundColor))
            }
            if let failure=runtime.failure {
                ContentUnavailableView {Label(runtime.crashed ? "Page stopped" : "Unable to load page",systemImage:"exclamationmark.triangle")} description:{Text(failure)} actions:{Button("Reload"){runtime.failure=nil;runtime.webView.reload()}.buttonStyle(.glass)}
                .frame(maxWidth:.infinity,maxHeight:.infinity).background(Color(nsColor:.textBackgroundColor))
            }
        }
        .clipShape(.rect(cornerRadius:8))
        .overlay(alignment:.top){if runtime.isLoading {ProgressView(value:runtime.progress).progressViewStyle(.linear).tint(.accentColor).frame(height:2)}}
        .overlay(RoundedRectangle(cornerRadius:8).strokeBorder(.primary.opacity(0.08),lineWidth:1))
        .accessibilityIdentifier("page-\(id)")
    }
}
struct WebContentView: NSViewRepresentable {
    let runtime: TabRuntime
    func makeNSView(context: Context) -> WKWebView {runtime.webView}
    func updateNSView(_ view: WKWebView,context: Context) {}
}
private struct FindBar: View {
    @Bindable var session: BrowserSession
    @FocusState private var focused: Bool
    var body: some View {
        HStack {
            TextField("Find in page",text:$session.findText).textFieldStyle(.bordered).focused($focused).onSubmit{session.find()}.accessibilityIdentifier("find-field")
            Text(session.findResult).foregroundStyle(.secondary)
            Button("Previous",systemImage:"chevron.up"){session.find(backwards:true)}.labelStyle(.iconOnly)
            Button("Next",systemImage:"chevron.down"){session.find()}.labelStyle(.iconOnly)
            Button("Close Find",systemImage:"xmark"){session.findVisible=false}.labelStyle(.iconOnly)
        }.padding(8).onAppear{focused=true}.onExitCommand{session.findVisible=false}
    }
}
