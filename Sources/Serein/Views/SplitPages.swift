import AppKit
import SwiftUI

/// Native divider geometry is the only AppKit boundary here. Browser state,
/// page identity and chrome remain owned by BrowserSession and PagePane.
struct SplitPages:NSViewRepresentable {
    let session:BrowserSession
    let ids:[UUID]
    func makeNSView(context:Context)->BrowserGridSplitView {
        let view=BrowserGridSplitView(vertical:true)
        configure(view)
        return view
    }
    func updateNSView(_ view:BrowserGridSplitView,context:Context) {
        if view.paneIDs != ids {configure(view)}
    }
    private func configure(_ root:BrowserGridSplitView) {
        root.subviews.forEach{$0.removeFromSuperview()}
        root.paneIDs=ids;root.needsInitialDivider=true
        func pane(_ id:UUID)->NSView {
            let host=NSHostingView(rootView:PagePane(session:session,id:id))
            host.safeAreaRegions=[]
            host.frame=NSRect(x:0,y:0,width:370,height:326)
            host.autoresizingMask=[.width,.height]
            return host
        }
        func column(_ ids:[UUID])->NSView {
            guard ids.count==2 else{return pane(ids[0])}
            let column=BrowserGridSplitView(vertical:false)
            for id in ids {column.addArrangedSubview(pane(id))}
            return column
        }
        if ids.count>2 {
            root.addArrangedSubview(column(Array(ids.prefix(2))))
            root.addArrangedSubview(column(Array(ids.dropFirst(2))))
        } else {
            for id in ids {root.addArrangedSubview(pane(id))}
        }
        root.needsLayout=true
    }
}

final class BrowserGridSplitView:NSSplitView,NSSplitViewDelegate {
    var paneIDs:[UUID]=[]
    var needsInitialDivider=true
    override var isFlipped:Bool {true}
    override var dividerThickness:CGFloat {8}
    init(vertical:Bool) {
        super.init(frame:NSRect(x:0,y:0,width:750,height:660))
        isVertical=vertical;dividerStyle = .thin;delegate=self
        autoresizingMask=[.width,.height]
    }
    required init?(coder:NSCoder){fatalError("Not supported")}
    override func layout() {
        super.layout()
        guard needsInitialDivider,window != nil,subviews.count==2 else{return}
        let length=isVertical ? bounds.width : bounds.height
        guard length>dividerThickness else{return}
        needsInitialDivider=false
        setPosition((length-dividerThickness)/2,ofDividerAt:0)
    }
    func splitView(_ splitView:NSSplitView,constrainMinCoordinate proposedMinimumPosition:CGFloat,ofSubviewAt dividerIndex:Int)->CGFloat {
        max(proposedMinimumPosition,isVertical ? 120 : 100)
    }
    func splitView(_ splitView:NSSplitView,constrainMaxCoordinate proposedMaximumPosition:CGFloat,ofSubviewAt dividerIndex:Int)->CGFloat {
        min(proposedMaximumPosition,(isVertical ? bounds.width : bounds.height)-dividerThickness-(isVertical ? 120 : 100))
    }
}
