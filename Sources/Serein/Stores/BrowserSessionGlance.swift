import Foundation

extension BrowserSession {
    func openGlance(_ url:URL,from owner:UUID) {
        guard ["http","https"].contains(url.scheme?.lowercased() ?? ""),
              state.visibleTabs.contains(where:{$0.id==owner}) else{return}
        if let existing=state.glance(for:owner) {
            if existing.url==url.absoluteString {select(existing.id);return}
            close(existing.id) { [weak self] closed in if closed {self?.openGlance(url,from:owner)} }
            return
        }
        let previous=state.selectedTabID,highlighted=tabSelection.ids
        guard let id=state.openGlance(url:url.absoluteString,from:owner) else{return}
        extensions?.controller.didOpenTab(bridge(id));tabSelection.selectOnly(id)
        publishSelection(previousActive:previous,previousHighlighted:highlighted)
    }
    func expandGlance() {
        guard let preview=state.activeGlance else{return}
        state.expandGlance(preview.id);select(preview.id)
    }
    func splitGlance() {
        guard let preview=state.activeGlance else{return}
        state.splitGlance(preview.id);select(preview.id)
    }
    func closeGlance() {if let preview=state.activeGlance {close(preview.id)}}
}
