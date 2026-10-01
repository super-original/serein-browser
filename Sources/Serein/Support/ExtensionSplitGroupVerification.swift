import AppKit
import WebKit

/// Observe real extension promises and events, not only native delegate calls.
@MainActor enum ExtensionSplitGroupVerification {
    static func run(manager:BrowserManager,context:WKWebExtensionContext,name:String) async->[RuntimeVerification.Result] {
        let previous=manager.active,session=manager.newWindow()
        defer{session.window?.close();previous?.window?.makeKeyAndOrderFront(nil)}
        let resource=context.baseURL.appendingPathComponent("public.html")
        let observer=session.newTab(url:resource.absoluteString),view=session.runtime(observer).webView
        for _ in 0..<100 {
            if view.url==resource && !view.isLoading {break}
            try? await Task.sleep(for:.milliseconds(50))
        }
        let urls=["http://127.0.0.1:8765/index.html?pin-group=\(name)-a","http://127.0.0.1:8765/second.html?pin-group=\(name)-b"]
        let ids=urls.map{session.newTab(url:$0,select:false)}
        session.state.setSplitTabs(ids);session.select(ids[0]);session.state.setSplitFraction(0.41,at:0)
        let value=try? await view.callAsyncJavaScript("""
        const events=[];
        const tabs=(await browser.tabs.query({})).filter(tab=>urls.includes(tab.url));
        if(tabs.length!==2) return {error:'Expected two owned group tabs',tabs};
        const ids=tabs.map(tab=>tab.id);
        const listener=(id,change)=>{if(ids.includes(id) && typeof change.pinned==='boolean') events.push({id,pinned:change.pinned});};
        const pause=ms=>new Promise(resolve=>setTimeout(resolve,ms));
        async function settled(count) {
          for(let i=0;i<30 && events.length<count;i++) await pause(50);
        }
        browser.tabs.onUpdated.addListener(listener);
        try {
          await browser.tabs.update(ids[0],{pinned:true});await settled(2);
          const pinned=await Promise.all(ids.map(id=>browser.tabs.get(id)));
          const pinEvents=events.slice();
          await browser.tabs.update(ids[1],{pinned:true});await pause(200);
          const repeated=events.slice();
          await browser.tabs.update(ids[1],{pinned:false});await settled(4);
          const unpinned=await Promise.all(ids.map(id=>browser.tabs.get(id)));
          return {allPinned:pinned.every(tab=>tab.pinned),allUnpinned:unpinned.every(tab=>!tab.pinned),
            pinEventsOnce:ids.every(id=>pinEvents.filter(e=>e.id===id && e.pinned).length===1) && pinEvents.length===2,
            repeatedPinSilent:repeated.length===pinEvents.length,
            unpinEventsOnce:ids.every(id=>events.filter(e=>e.id===id && !e.pinned).length===1) && events.length===4,
            events};
        } catch(error){return {error:String(error),events};}
        finally{browser.tabs.onUpdated.removeListener(listener);}
        """,arguments:["urls":urls],in:nil,contentWorld:.page) as? [String:Any]
        var results=[RuntimeVerification.Result]()
        for field in ["allPinned","allUnpinned","pinEventsOnce","repeatedPinSilent","unpinEventsOnce"] {
            results.append(.init(name:name+"-split-group-"+field,passed:value?[field] as? Bool==true,detail:String(describing:value)))
        }
        results.append(.init(name:name+"-split-group-native-state",passed:session.state.splitTabIDs==ids && session.state.selectedTabID==ids[0] && abs(session.state.splitFraction(at:0)-0.41)<0.001,detail:"Real browser.tabs.update promises; group selection and divider retained"))
        return results
    }
}
