import SwiftUI

/// Zen's 80%-width, full-height preview; controls use native macOS glass.
struct GlancePages:View {
    let session:BrowserSession
    let owner:UUID
    let preview:UUID
    var body:some View {
        GeometryReader {geometry in
            let width=min(geometry.size.width*0.8,max(0,geometry.size.width-112))
            ZStack {
                PagePane(session:session,id:owner)
                    .scaleEffect(0.97).opacity(0.3).allowsHitTesting(false).accessibilityHidden(true)
                Color.clear.contentShape(Rectangle())
                    .onTapGesture{session.close(preview)}.accessibilityHidden(true)
                PagePane(session:session,id:preview)
                    .frame(width:width,height:geometry.size.height)
                    .clipShape(.rect(cornerRadius:8))
                    .shadow(color:.black.opacity(0.15),radius:8)
                VStack(spacing:12) {
                    control("Close Preview",symbol:"xmark",id:"glance-close"){session.close(preview)}
                    control("Expand Preview",symbol:"arrow.up.left.and.arrow.down.right",id:"glance-expand"){session.expandGlance()}
                    control("Split Preview",symbol:"rectangle.split.2x1",id:"glance-split"){session.splitGlance()}
                }
                .padding(12).frame(width:56,height:144,alignment:.top)
                .position(x:(geometry.size.width+width)/2+28,y:15+72)
            }
            .accessibilityElement(children:.contain)
            .accessibilityLabel("Link Preview")
        }
        .onAppear {DispatchQueue.main.async {session.focusContent(ifSelected:preview)}}
        .onDisappear {
            let selected=session.state.selectedTabID
            DispatchQueue.main.async {session.focusContent(ifSelected:selected)}
        }
    }
    private func control(_ title:String,symbol:String,id:String,action:@escaping ()->Void)->some View {
        Button(action:action){Image(systemName:symbol).frame(width:20,height:20)}
            .buttonStyle(.glass).buttonBorderShape(.circle)
            .frame(width:32,height:32).accessibilityLabel(title).accessibilityIdentifier(id).help(title)
    }
}
