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
        func bind(_ view:BrowserGridSplitView,_ index:Int) {
            view.fraction=session.state.splitFraction(at:index)
            view.onUserResize={ [weak session] value in
                guard let session,session.state.splitTabIDs==ids else{return}
                session.state.setSplitFraction(value,at:index)
            }
        }
        bind(root,0)
        func pane(_ id:UUID)->NSView {
            let host=NSHostingView(rootView:PagePane(session:session,id:id,presentation:.split(ids)))
            host.safeAreaRegions=[]
            host.frame=NSRect(x:0,y:0,width:370,height:326)
            host.autoresizingMask=[.width,.height]
            return host
        }
        func column(_ ids:[UUID],_ index:Int)->NSView {
            guard ids.count==2 else{return pane(ids[0])}
            let column=BrowserGridSplitView(vertical:false)
            bind(column,index)
            for id in ids {column.addArrangedSubview(pane(id))}
            return column
        }
        if ids.count>2 {
            root.addArrangedSubview(column(Array(ids.prefix(2)),1))
            root.addArrangedSubview(column(Array(ids.dropFirst(2)),2))
        } else {
            for id in ids {root.addArrangedSubview(pane(id))}
        }
        root.needsLayout=true
    }
}

final class BrowserGridSplitView:NSSplitView,NSSplitViewDelegate {
    var paneIDs:[UUID]=[]
    var needsInitialDivider=true
    var fraction=0.5
    var onUserResize:((Double)->Void)?
    private var resizeToken:NotificationCenter.ObservationToken?
    private var lastLayoutSize=NSSize.zero
    private var applyingFraction=false
    override var isFlipped:Bool {true}
    override var dividerThickness:CGFloat {8}
    init(vertical:Bool) {
        super.init(frame:NSRect(x:0,y:0,width:750,height:660))
        isVertical=vertical;dividerStyle = .thin;delegate=self
        autoresizingMask=[.width,.height]
        resizeToken=NotificationCenter.default.addObserver(of:self,for:NotificationCenter.BaseMessageIdentifier<NSSplitView.DidResizeSubviewsMessage>()) { [weak self] message in
            guard let self,message.userResize,!self.applyingFraction,self.subviews.count==2 else{return}
            let available=(self.isVertical ? self.bounds.width : self.bounds.height)-self.dividerThickness
            guard available>0 else{return}
            let size=self.isVertical ? self.subviews[0].frame.width : self.subviews[0].frame.height
            self.fraction=Double(size/available)
            self.onUserResize?(self.fraction)
        }
    }
    required init?(coder:NSCoder){fatalError("Not supported")}
    override func layout() {
        super.layout()
        guard window != nil,subviews.count==2,needsInitialDivider || lastLayoutSize != bounds.size else{return}
        let length=isVertical ? bounds.width : bounds.height
        guard length>dividerThickness else{return}
        needsInitialDivider=false;lastLayoutSize=bounds.size
        let available=length-dividerThickness,minimum=min(isVertical ? 120.0 : 100.0,available/2)
        applyingFraction=true
        setPosition(min(available-minimum,max(minimum,available*fraction)),ofDividerAt:0)
        applyingFraction=false
    }
    func splitView(_ splitView:NSSplitView,constrainMinCoordinate proposedMinimumPosition:CGFloat,ofSubviewAt dividerIndex:Int)->CGFloat {
        max(proposedMinimumPosition,isVertical ? 120 : 100)
    }
    func splitView(_ splitView:NSSplitView,constrainMaxCoordinate proposedMaximumPosition:CGFloat,ofSubviewAt dividerIndex:Int)->CGFloat {
        min(proposedMaximumPosition,(isVertical ? bounds.width : bounds.height)-dividerThickness-(isVertical ? 120 : 100))
    }
}
