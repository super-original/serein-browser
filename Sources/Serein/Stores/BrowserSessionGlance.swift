import Foundation
import WebKit

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
        tabSelection.selectOnly(id);extensions?.controller.didOpenTab(bridge(id))
        publishSelection(previousActive:previous,previousHighlighted:highlighted)
    }
    func newPopup(_ target:URL?,from owner:UUID,configuration:WKWebViewConfiguration)->WKWebView {
        let previous=state.selectedTabID,highlighted=tabSelection.ids
        guard let target,state.shouldPreviewNewTab(target,from:owner,enabled:UserDefaults.standard.object(forKey:"previewExternalPinnedLinks") as? Bool ?? true),
              let id=state.openGlance(url:"about:blank",from:owner) else {
            return runtime(newTab(configuration:configuration,opener:owner)).webView
        }
        // Return a view built from WebKit's supplied configuration. WebKit loads
        // the original request, preserving POST bodies and window relationships.
        runtimes[id]=TabRuntime(id:id,session:self,configuration:configuration)
        tabSelection.selectOnly(id)
        extensions?.controller.didOpenTab(bridge(id))
        publishSelection(previousActive:previous,previousHighlighted:highlighted)
        return runtime(id).webView
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
