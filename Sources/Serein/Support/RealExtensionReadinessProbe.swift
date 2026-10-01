import WebKit

/// Read-only diagnostics in an unmodified real extension's options page.
/// A responsive API or later response never replaces the original timeout failure.
@MainActor enum RealExtensionReadinessProbe {
    static func lateReply(_ view:WKWebView) async->String {
        let result=try? await view.callAsyncJavaScript("""
        const started=performance.now();
        const reply=await Promise.race([
          globalThis.__sereinOptionsReply,
          new Promise(resolve=>setTimeout(()=>resolve({status:'timeout'}),20000))
        ]);
        return JSON.stringify({status:reply?.status,elapsed:performance.now()-started,
          hasEasyList:Array.isArray(reply?.value?.enabledRulesets)&&reply.value.enabledRulesets.includes('easylist'),
          optionsStillLoading:document.body.classList.contains('loading')});
        """,arguments:[:],in:nil,contentWorld:.page)
        return result as? String ?? "Late reply could not be evaluated."
    }
    static func inspect(_ view:WKWebView) async->String {
        let result=try? await view.callAsyncJavaScript("""
        const measure=async(name,operation)=>{
          const started=performance.now();let timer;
          try {
            const value=await Promise.race([
              Promise.resolve().then(operation).then(value=>({status:'response',count:Array.isArray(value)?value.length:typeof value==='object'&&value!==null?Object.keys(value).length:null})),
              new Promise(resolve=>{timer=setTimeout(()=>resolve({status:'timeout'}),3000);})
            ]);
            return {name,...value,elapsed:performance.now()-started};
          } catch(error){return {name,status:'rejected',error:String(error),elapsed:performance.now()-started};}
          finally{clearTimeout(timer);}
        };
        const apis=await Promise.all([
          measure('permissions.getAll',()=>browser.permissions.getAll()),
          measure('storage.local.get',()=>browser.storage.local.get(null)),
          measure('storage.session.get',()=>browser.storage.session.get(null)),
          measure('storage.managed.get',()=>browser.storage.managed.get(null)),
          measure('scripting.getRegisteredContentScripts',()=>browser.scripting.getRegisteredContentScripts()),
          measure('dnr.getEnabledRulesets',()=>browser.declarativeNetRequest.getEnabledRulesets()),
          measure('dnr.getDynamicRules',()=>browser.declarativeNetRequest.getDynamicRules()),
          measure('dnr.getSessionRules',()=>browser.declarativeNetRequest.getSessionRules())
        ]);
        return JSON.stringify({apis,
          optionsStillLoading:document.body.classList.contains('loading'),
          optionsHasEasyList:Array.isArray(self.cachedRulesetData?.enabledRulesets)&&self.cachedRulesetData.enabledRulesets.includes('easylist'),
          pageReadyState:document.readyState,resourceOrigin:browser.runtime.getURL('')});
        """,arguments:[:],in:nil,contentWorld:.page)
        return result as? String ?? "Readiness diagnostics could not be evaluated."
    }
}
