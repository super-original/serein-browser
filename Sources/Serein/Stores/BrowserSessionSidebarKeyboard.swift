import Foundation

extension BrowserSession {
    func moveSidebarSelection(from source:UUID,direction:Int,extending:Bool)->UUID? {
        guard let target=state.sidebarNeighbor(of:source,direction:direction) else{return nil}
        let previous=state.selectedTabID,highlighted=tabSelection.ids
        if let preview=state.activeGlance {state.expandGlance(preview.id)}
        if extending {
            if !tabSelection.ids.contains(source) {tabSelection.selectOnly(source)}
            tabSelection.range(to:target,in:state.sidebarTabIDs)
        } else {tabSelection.selectOnly(target)}
        state.select(target)
        contentFocusRequest=nil;sidebarKeyboardFocus=target
        publishSelection(previousActive:previous,previousHighlighted:highlighted)
        return target
    }
}
