import Foundation
import NaturalLanguage
import WebKit
import SereinCore

/// Local, bounded top-document detection. No page text leaves this process.
/// Apple's model is not Chromium/Firefox CLD and does not imply identical output.
@MainActor enum ExtensionPageLanguage {
    private static var pending:[ObjectIdentifier:Int]=[:]
    // Do not materialize the entire document's innerText before truncating it.
    // Bound both traversal and the text crossing the WebKit process boundary.
    private static let sampleScript="""
    const root=document.body;
    if(!root) return '';
    const hidden=node=>{
      const style=getComputedStyle(node);
      return node.hidden || style.display==='none' || style.visibility==='hidden' || style.visibility==='collapse';
    };
    if(hidden(root)) return '';
    const stop={},parts=[];
    let visited=0,remaining=32768;
    const walker=document.createTreeWalker(root,NodeFilter.SHOW_ELEMENT|NodeFilter.SHOW_TEXT,{
      acceptNode(node){
        if(++visited>8192) throw stop;
        if(node.nodeType===Node.ELEMENT_NODE) {
          return ['SCRIPT','STYLE','NOSCRIPT','TEMPLATE'].includes(node.tagName)||hidden(node) ? NodeFilter.FILTER_REJECT : NodeFilter.FILTER_SKIP;
        }
        return NodeFilter.FILTER_ACCEPT;
      }
    });
    try {
      while(remaining>0) {
        const node=walker.nextNode();if(!node) break;
        const text=node.data.slice(0,remaining);
        parts.push(text);remaining-=text.length;
        if(remaining>0){parts.push(' ');remaining--;}
      }
    } catch(error){if(error!==stop) throw error;}
    return parts.join('');
    """
    static func detect(tab:ExtensionTab,context:WKWebExtensionContext,completion:@escaping (Locale?,(any Error)?)->Void) {
        guard let session=tab.session,!session.state.isPrivate,
              let runtime=session.runtimes[tab.id],let view=runtime.loadedWebView,
              !runtime.isLoading,let url=view.url,["http","https"].contains(url.scheme?.lowercased() ?? "") else {
            completion(nil,ExtensionValidationError.invalid("Language detection requires a loaded HTTP(S) tab."));return
        }
        let document=runtime.documentID
        let authorized:()->Bool = { [weak session,weak runtime,weak view,weak context,weak tab] in
            guard let session,let runtime,let view,let context,let tab,let host=session.extensions,let id=host.contexts.first(where:{$0.value===context})?.key,
                  host.records.contains(where:{$0.id==id && $0.enabled}),
                  session.state.tabs.contains(where:{$0.id==tab.id}),runtime.documentID==document,
                  runtime.loadedWebView === view,!runtime.isLoading,view.url==url else{return false}
            return context.hasPermission(WKWebExtension.Permission(rawValue:"tabs"),in:tab) || context.hasAccess(to:url,in:tab)
        }
        guard authorized() else{completion(nil,ExtensionValidationError.invalid("Language detection requires current tab access."));return}
        let key=ObjectIdentifier(context)
        guard pending[key,default:0]<4,pending.values.reduce(0,+)<16 else{completion(nil,ExtensionValidationError.invalid("Too many language requests are pending."));return}
        pending[key,default:0] += 1
        let request=LanguageRequest {locale,error in
            let remaining=max(0,pending[key,default:0]-1)
            pending[key]=remaining==0 ? nil : remaining
            completion(locale,error)
        }
        request.startTimeout()
        view.callAsyncJavaScript(sampleScript,arguments:[:],in:nil,in:.defaultClient) {result in
            guard request.isPending else{return}
            guard authorized() else{request.finish(nil,ExtensionValidationError.invalid("The document or extension access changed during language detection."));return}
            switch result {
            case .success(let value):
                guard let text=value as? String,text.utf16.count<=32768 else{request.finish(nil,ExtensionValidationError.invalid("Invalid language text response."));return}
                Task {
                    let language=await Task.detached(priority:.utility) {
                        NLLanguageRecognizer.dominantLanguage(for:text)?.rawValue ?? "und"
                    }.value
                    guard request.isPending else{return}
                    guard authorized() else{request.finish(nil,ExtensionValidationError.invalid("The document or extension access changed during language classification."));return}
                    request.finish(Locale(identifier:language),nil)
                }
            case .failure(let error):request.finish(nil,error)
            }
        }
    }
}

@MainActor private final class LanguageRequest {
    private var reply:((Locale?,(any Error)?)->Void)?
    private var timeout:Task<Void,Never>?
    var isPending:Bool {reply != nil}
    init(_ reply:@escaping (Locale?,(any Error)?)->Void){self.reply=reply}
    func startTimeout() {
        timeout=Task { [self] in
            do {try await Task.sleep(for:.seconds(5))} catch {return}
            finish(nil,ExtensionValidationError.invalid("Language detection timed out."))
        }
    }
    func finish(_ locale:Locale?,_ error:(any Error)?) {
        guard let reply else{return}
        self.reply=nil;timeout?.cancel();timeout=nil;reply(locale,error)
    }
}
