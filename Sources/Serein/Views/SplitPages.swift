import AppKit
import SwiftUI
import SereinCore

/// Native divider geometry is the only AppKit boundary here. Browser state,
/// page identity and chrome remain owned by BrowserSession and PagePane.
struct SplitPages:NSViewRepresentable {
    let session:BrowserSession
    let ids:[UUID]
    let layout:SplitLayout
    func makeNSView(context:Context)->BrowserGridSplitView {
        let view=BrowserGridSplitView(vertical:true)
        configure(view)
        return view
    }
    func updateNSView(_ view:BrowserGridSplitView,context:Context) {
        if view.paneIDs != ids || view.arrangement != layout {configure(view)}
    }
    private func configure(_ root:BrowserGridSplitView) {
        root.subviews.forEach{$0.removeFromSuperview()}
        root.paneIDs=ids;root.arrangement=layout;root.isVertical=layout != .rows;root.needsInitialDivider=true
        root.dividerFractions=nil;root.onDividersResize=nil
        func bind(_ view:BrowserGridSplitView,_ index:Int) {
            view.fraction=session.state.splitFraction(at:index)
            view.onUserResize={ [weak session] value in
                guard let session,session.state.splitTabIDs==ids,session.state.resolvedSplitLayout==layout else{return}
                session.state.setSplitFraction(value,at:index)
            }
        }
        bind(root,0)
        func pane(_ id:UUID)->NSView {
            let host=NSHostingView(rootView:PagePane(session:session,id:id,presentation:.split(ids,layout)))
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
        if layout != .grid {
            root.dividerFractions=(0..<(ids.count-1)).map{session.state.splitFraction(at:$0)}
            root.onDividersResize={ [weak session] values in
                guard let session,session.state.splitTabIDs==ids,session.state.resolvedSplitLayout==layout else{return}
                for (index,value) in values.enumerated(){session.state.setSplitFraction(value,at:index)}
            }
            for id in ids {root.addArrangedSubview(pane(id))}
        } else if ids.count>2 {
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
    var arrangement:SplitLayout = .grid
    var dividerFractions:[Double]?
    var onDividersResize:(([Double])->Void)?
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
            guard let self,message.userResize,!self.applyingFraction,self.subviews.count>=2 else{return}
            let available=(self.isVertical ? self.bounds.width : self.bounds.height)-self.dividerThickness*CGFloat(self.subviews.count-1)
            guard available>0 else{return}
            if self.dividerFractions != nil {
                var cumulative:CGFloat=0
                let values=self.subviews.dropLast().map {view in
                    cumulative += self.isVertical ? view.frame.width : view.frame.height
                    return Double(cumulative/available)
                }
                self.dividerFractions=values;self.onDividersResize?(values);return
            }
            let size=self.isVertical ? self.subviews[0].frame.width : self.subviews[0].frame.height
            self.fraction=Double(size/available)
            self.onUserResize?(self.fraction)
        }
    }
    required init?(coder:NSCoder){fatalError("Not supported")}
    override func layout() {
        super.layout()
        guard window != nil,subviews.count>=2,needsInitialDivider || lastLayoutSize != bounds.size else{return}
        let length=isVertical ? bounds.width : bounds.height
        guard length>dividerThickness else{return}
        needsInitialDivider=false;lastLayoutSize=bounds.size
        let available=length-dividerThickness*CGFloat(subviews.count-1)
        guard available>0 else{return}
        let minimum=min(isVertical ? 120.0 : 100.0,available/CGFloat(subviews.count))
        applyingFraction=true
        if let values=dividerFractions,values.count==subviews.count-1 {
            var prior:CGFloat=0
            for (index,value) in values.enumerated() {
                let remaining=CGFloat(subviews.count-index-1)
                let position=min(available-minimum*remaining,max(prior+minimum,available*value))
                setPosition(position+CGFloat(index)*dividerThickness,ofDividerAt:index)
                prior=position
            }
            applyingFraction=false;return
        }
        setPosition(min(available-minimum,max(minimum,available*fraction)),ofDividerAt:0)
        applyingFraction=false
    }
    private var minimumPaneLength:CGFloat {
        let available=(isVertical ? bounds.width : bounds.height)-dividerThickness*CGFloat(max(0,subviews.count-1))
        return min(isVertical ? 120 : 100,max(0,available/CGFloat(max(1,subviews.count))))
    }
    func splitView(_ splitView:NSSplitView,constrainMinCoordinate proposedMinimumPosition:CGFloat,ofSubviewAt dividerIndex:Int)->CGFloat {
        guard subviews.indices.contains(dividerIndex) else{return proposedMinimumPosition}
        let frame=subviews[dividerIndex].frame
        return max(proposedMinimumPosition,(isVertical ? frame.minX : frame.minY)+minimumPaneLength)
    }
    func splitView(_ splitView:NSSplitView,constrainMaxCoordinate proposedMaximumPosition:CGFloat,ofSubviewAt dividerIndex:Int)->CGFloat {
        guard subviews.indices.contains(dividerIndex+1) else{return proposedMaximumPosition}
        let frame=subviews[dividerIndex+1].frame
        return min(proposedMaximumPosition,(isVertical ? frame.maxX : frame.maxY)-dividerThickness-minimumPaneLength)
    }
}
