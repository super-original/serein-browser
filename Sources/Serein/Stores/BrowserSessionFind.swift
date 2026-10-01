import Foundation
import WebKit

extension BrowserSession {
    /// A completion from an earlier query/document must not label the current page.
    func find(backwards:Bool=false,completion:((Bool?)->Void)?=nil) {
        let request=UUID();findRequestID=request
        let query=findText
        findResult=""
        guard !query.isEmpty,let runtime=current else{completion?(nil);return}
        let document=runtime.documentID
        let view=runtime.webView
        let configuration=WKFindConfiguration()
        configuration.backwards=backwards;configuration.wraps=true
        view.find(query,configuration:configuration) { [weak self,weak runtime,weak view] result in
            guard let self,let runtime,let view,self.findVisible,
                  self.findRequestID==request,self.findText==query,
                  self.state.selectedTabID==runtime.id,runtime.documentID==document,
                  runtime.loadedWebView===view else{completion?(nil);return}
            self.findResult=result.matchFound ? "" : "No matches"
            completion?(result.matchFound)
        }
    }

    func closeFind() {
        if findVisible {contentFocusRequest=state.selectedTabID}
        findVisible=false;findRequestID=UUID();findResult=""
        // FindBar returns focus after its field actually leaves the hierarchy.
    }
}
