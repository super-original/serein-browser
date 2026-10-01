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
                    if let preview=session.state.activeGlance,let owner=preview.glanceParentID {
                        GlancePages(session:session,owner:owner,preview:preview.id)
                    } else if session.state.splitTabIDs.count>=2 {
                        SplitPages(session:session,ids:session.state.splitTabIDs)
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
enum PagePresentation {
    case single,split([UUID]),glance(owner:UUID,preview:UUID)
    @MainActor func isCurrent(in session:BrowserSession,tab:UUID)->Bool {
        switch self {
        case .single:return session.state.activeGlance==nil && session.state.splitTabIDs.count<2 && session.state.selectedTabID==tab
        case .split(let ids):return session.state.activeGlance==nil && ids==session.state.splitTabIDs && ids.contains(tab)
        case .glance(let owner,let preview):return session.state.activeGlance?.id==preview && session.state.activeGlance?.glanceParentID==owner && (tab==owner || tab==preview)
        }
    }
}
struct PagePane: View {
    let session: BrowserSession
    let id: UUID
    var presentation:PagePresentation = .single
    var body: some View {
        if session.state.tabs.contains(where:{$0.id==id}) {
            let runtime=session.runtime(id)
            ZStack {
                WebContentView(runtime:runtime,session:session,presentation:presentation).id(runtime.viewRevision).id(ObjectIdentifier(runtime))
                if session.state.tabs.first(where:{$0.id==id})?.url=="about:blank" {
                    VStack(spacing:12) {
                        Image(systemName:session.state.isPrivate ? "hand.raised" : "sparkle").font(.system(size:32,weight:.light))
                        Text(session.state.isPrivate ? "Private Browsing" : "New Tab").font(.title2)
                        Text(session.state.isPrivate ? "History and tabs from this window won’t be saved." : "⌘L to search or enter an address").foregroundStyle(.secondary)
                    }.frame(maxWidth:.infinity,maxHeight:.infinity).background(Color(nsColor:.textBackgroundColor))
                }
                if let failure=runtime.failure {
                    ContentUnavailableView {Label(runtime.crashed ? "Page stopped" : "Unable to load page",systemImage:"exclamationmark.triangle")} description:{Text(failure)} actions:{Button("Reload"){runtime.reload()}.buttonStyle(.glass).accessibilityIdentifier("page-error-reload")}
                    .frame(maxWidth:.infinity,maxHeight:.infinity).background(Color(nsColor:.textBackgroundColor))
                }
            }
            .overlay(alignment:.top){if runtime.isLoading {ProgressView(value:runtime.progress).progressViewStyle(.linear).tint(.accentColor).frame(height:2)}}
            .overlay(RoundedRectangle(cornerRadius:8).strokeBorder(
                session.state.secondaryTabID != nil && session.state.selectedTabID == id ? Color.accentColor : Color.primary.opacity(0.08),
                lineWidth:session.state.secondaryTabID != nil && session.state.selectedTabID == id ? 2 : 1
            ).allowsHitTesting(false))
        }
    }
}
struct WebContentView: NSViewRepresentable {
    let runtime: TabRuntime
    let session: BrowserSession
    let presentation:PagePresentation
    func makeNSView(context: Context) -> NSView {
        let container=WebContentContainer(frame:NSRect(x:0,y:0,width:800,height:600))
        guard presentation.isCurrent(in:session,tab:runtime.id),runtime.session === session,session.runtimes[runtime.id] === runtime,session.state.tabs.contains(where:{$0.id==runtime.id}) else{return container}
        container.runtime=runtime
        let view=runtime.webView
        context.coordinator.attach(to:view)
        view.frame=container.bounds;view.autoresizingMask=[.width,.height]
        container.addSubview(view)
        return container
    }
    func makeCoordinator() -> Coordinator {Coordinator(runtime:runtime)}
    static func dismantleNSView(_ view:NSView,coordinator:Coordinator) {if let gesture=coordinator.gesture {coordinator.view?.removeGestureRecognizer(gesture)}}
    @MainActor final class Coordinator:NSObject,NSGestureRecognizerDelegate {
        let runtime:TabRuntime
        weak var view:WKWebView?
        var gesture:NSClickGestureRecognizer?
        init(runtime:TabRuntime){self.runtime=runtime}
        func attach(to view:WKWebView) {
            guard self.view !== view else{return}
            if let gesture {self.view?.removeGestureRecognizer(gesture)}
            let gesture=NSClickGestureRecognizer(target:self,action:#selector(focus))
            gesture.delaysPrimaryMouseButtonEvents=false;gesture.delegate=self
            view.addGestureRecognizer(gesture);self.gesture=gesture;self.view=view
        }
        @objc func focus(){if runtime.session?.state.secondaryTabID != nil,runtime.session?.state.selectedTabID != runtime.id{runtime.session?.select(runtime.id)}}
        func gestureRecognizer(_ gestureRecognizer:NSGestureRecognizer,shouldRecognizeSimultaneouslyWith other:NSGestureRecognizer)->Bool{true}
    }
    func updateNSView(_ view: NSView,context: Context) {
        guard let container=view as? WebContentContainer,presentation.isCurrent(in:session,tab:runtime.id),
              runtime.session === session,session.runtimes[runtime.id] === runtime,session.state.tabs.contains(where:{$0.id==runtime.id}) else{return}
        container.runtime=runtime
        let page=runtime.webView
        context.coordinator.attach(to:page)
        if page.superview !== container {
            page.frame=container.bounds;page.autoresizingMask=[.width,.height]
            container.addSubview(page)
        }
        DispatchQueue.main.async {session.completeContentFocusRequest()}
    }
}
@MainActor private final class WebContentContainer:NSView {
    weak var runtime:TabRuntime?
    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        runtime?.restoreFocusIfNeeded(in:window)
        runtime?.session?.completeContentFocusRequest()
    }
}
private struct FindBar: View {
    @Bindable var session: BrowserSession
    @FocusState private var focused: Bool
    var body: some View {
        HStack {
            TextField("Find in page",text:Binding(get:{session.findText},set:{if session.findText != $0 {session.findText=$0;session.find()}})).textFieldStyle(.bordered).focused($focused).onSubmit{session.find()}.accessibilityIdentifier("find-field")
            Text(session.findResult).foregroundStyle(.secondary)
            Button("Previous",systemImage:"chevron.up"){session.find(backwards:true)}.labelStyle(.iconOnly)
            Button("Next",systemImage:"chevron.down"){session.find()}.labelStyle(.iconOnly)
            Button("Close Find",systemImage:"xmark"){session.closeFind()}.labelStyle(.iconOnly)
        }.padding(8).onAppear{focused=true}.onExitCommand{session.closeFind()}
        .onDisappear {
            focused=false
            let selected=session.state.selectedTabID
            DispatchQueue.main.async {session.focusContent(ifSelected:selected)}
        }
    }
}
