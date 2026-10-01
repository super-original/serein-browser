import Foundation
import WebKit
import SereinCore

/// Unmodified source-built JSON Formatter 0.8.0; never a store-package claim.
@MainActor enum RealFormatterVerification {
    static func run(root:URL) async->[RuntimeVerification.Result] {
        var results:[RuntimeVerification.Result]=[]
        func check(_ name:String,_ pass:Bool,_ detail:String=""){results.append(.init(name:"real-formatter-"+name,passed:pass,detail:detail))}
        func wait(_ condition:@MainActor () async->Bool) async->Bool {
            for _ in 0..<100 {if await condition(){return true};try? await Task.sleep(for:.milliseconds(100))};return false
        }
        func js(_ view:WKWebView,_ code:String) async->Bool {(try? await view.evaluateJavaScript(code)) as? Bool == true}
        let args=ProcessInfo.processInfo.arguments
        guard let argument=args.firstIndex(of:"--real-formatter"),args.indices.contains(argument+1) else{check("source",false,"No source-built package path");return results}
        let temporary=FileManager.default.temporaryDirectory.appendingPathComponent("serein-real-formatter-"+UUID().uuidString)
        let manager=BrowserManager(root:temporary),id=UUID()
        let host=manager.extensions,session=manager.newWindow(),privateSession=manager.newWindow(isPrivate:true)
        defer {session.window?.close();privateSession.window?.close();try? FileManager.default.removeItem(at:temporary)}
        do {
            let source=URL(fileURLWithPath:args[argument+1]),target=host.root.appendingPathComponent(id.uuidString)
            let (_,ledger)=try host.preparePackage(source,at:target)
            let ext=try await ExtensionPackageLoader.load(target)
            check("unaltered-manifest",!ledger.manifestWasNormalized && ext.version=="0.8.0","Pinned source build; hashes in json-formatter-build.json")
            let record=InstalledExtension(id:id,name:"JSON Formatter",version:"0.8.0",enabled:true,permissions:ext.requestedPermissions.map(\.rawValue),hosts:[],capabilityLedger:ledger)
            host.records.append(record);try await host.load(record)
            guard let context=host.contexts[id] else{throw ExtensionValidationError.invalid("No formatter context")}
            context.setPermissionStatus(.grantedExplicitly,for:try WKWebExtension.MatchPattern(string:"http://127.0.0.1/*"))
            let tab=session.newTab(url:"http://127.0.0.1:8765/formatter.json"),view=session.runtime(tab).webView
            let formatted=await wait{await js(view,"!!document.querySelector('#jsonFormatterParsed .entry')")}
            check("isolated-content-formats-json",formatted)
            check("untitled-document-tab-name",session.state.tabs.first{$0.id==tab}?.title=="formatter.json")
            check("untrusted-json-remains-text",await js(view,"document.querySelector('#jsonFormatterParsed')?.textContent.includes('<img src=x onerror=alert(1)>') === true && document.images.length === 0"))
            check("main-world-json-global",await wait{await js(view,"window.json?.project === 'Serein' && window.json.nested.items.length === 4")})
            check("raw-control",await js(view,"document.querySelector('#buttonPlain')?.dispatchEvent(new MouseEvent('mousedown',{bubbles:true}));document.querySelector('#jsonFormatterParsed')?.hidden === true && document.querySelector('#jsonFormatterRaw')?.hidden === false"))
            check("parsed-control",await js(view,"document.querySelector('#buttonFormatted')?.dispatchEvent(new MouseEvent('mousedown',{bubbles:true}));document.querySelector('#jsonFormatterParsed')?.hidden === false && document.querySelector('#jsonFormatterRaw')?.hidden === true"))
            if let options=context.optionsPageURL {
                let optionTab=session.newTab(url:options.absoluteString),optionView=session.runtime(optionTab).webView
                _=await wait{await js(optionView,"!!document.querySelector('input[name=theme]:checked')")}
                _=await js(optionView,"document.querySelector('input[value=force_dark]').click();true")
                var stored=false,storageDetail="No callback yet"
                let storageStart=Date()
                while !stored,Date().timeIntervalSince(storageStart)<5 {
                    do {
                        let reply=try await optionView.callAsyncJavaScript("""
                        try {
                          return await Promise.race([
                            new Promise(resolve=>chrome.storage.local.get('themeOverride',value=>resolve({status:'reply',matches:value.themeOverride === 'force_dark',kind:typeof value.themeOverride}))),
                            new Promise(resolve=>setTimeout(()=>resolve({status:'timeout'}),500))
                          ]);
                        } catch(error) {return {status:'error',error:String(error),chromeType:typeof chrome,browserType:typeof browser};}
                        """,arguments:[:],in:nil,contentWorld:.page) as? [String:Any]
                        stored=reply?["matches"] as? Bool==true;storageDetail=String(describing:reply)
                    } catch {storageDetail=error.localizedDescription}
                    if !stored {try? await Task.sleep(for:.milliseconds(100))}
                }
                check("original-options-storage",stored,"Original change listener writes asynchronously; bounded readback: \(storageDetail)")
                session.close(optionTab,ask:false)
                view.load(URLRequest(url:URL(string:"http://127.0.0.1:8765/formatter.json?formatter=theme")!))
                check("stored-theme-applies-on-navigation",await wait{
                    guard view.url?.query=="formatter=theme",!view.isLoading else{return false}
                    return await js(view,"!!document.querySelector('#jsonFormatterParsed .entry') && getComputedStyle(document.body).backgroundColor === 'rgb(26, 26, 26)' && !document.querySelector('#jfStyleEl')?.textContent.includes('@media (prefers-color-scheme: dark)')")
                })
            } else {check("original-options-storage",false,"No options page")}
            let deniedTab=session.newTab(url:"http://localhost:8765/formatter.json"),deniedView=session.runtime(deniedTab).webView
            let deniedLoaded=await wait{await js(deniedView,"document.querySelector('pre')?.textContent.includes('Serein') === true")}
            let deniedUnmodified=await js(deniedView,"!document.querySelector('#jsonFormatterParsed') && !window.json")
            check("ungranted-host-not-injected",deniedLoaded && deniedUnmodified)
            session.close(deniedTab,ask:false)
            let privateTab=privateSession.newTab(url:"http://127.0.0.1:8765/formatter.json"),privateView=privateSession.runtime(privateTab).webView
            let privateLoaded=await wait{await js(privateView,"document.querySelector('pre')?.textContent.includes('Serein') === true")}
            let privateUnmodified=await js(privateView,"!document.querySelector('#jsonFormatterParsed')")
            check("private-not-injected",privateLoaded && privateView.configuration.webExtensionController==nil && privateUnmodified)
            session.window?.makeKeyAndOrderFront(nil)
            try? "74-real-json-formatter".write(to:root.appendingPathComponent("capture-request"),atomically:true,encoding:.utf8)
            check("desktop-captured",await wait{FileManager.default.fileExists(atPath:root.appendingPathComponent("74-real-json-formatter.capture-finished").path)})
            do {
                let snapshot=try await PageSnapshot.capture(in:session)
                try snapshot.png.write(to:root.appendingPathComponent("diagnostic-json-formatter-internal-snapshot.png"),options:.atomic)
                check("internal-snapshot-captured",true,"Internal WebKit image, not desktop rendering evidence")
            } catch {check("internal-snapshot-captured",false,error.localizedDescription)}
            await host.setEnabled(id,false)
            view.load(URLRequest(url:URL(string:"http://127.0.0.1:8765/formatter.json?formatter=disabled")!))
            let disabledLoaded=await wait{
                guard view.url?.query=="formatter=disabled",!view.isLoading else{return false}
                return await js(view,"document.querySelector('pre')?.textContent.includes('Serein') === true")
            }
            let disabledUnmodified=await js(view,"!document.querySelector('#jsonFormatterParsed')")
            check("disable-stops-new-injection",host.contexts[id]==nil && disabledLoaded && disabledUnmodified)
            await host.setEnabled(id,true)
            view.load(URLRequest(url:URL(string:"http://127.0.0.1:8765/formatter.json?formatter=reenabled")!))
            check("reenable-retains-theme",await wait{
                guard view.url?.query=="formatter=reenabled",!view.isLoading else{return false}
                return await js(view,"!!document.querySelector('#jsonFormatterParsed .entry') && getComputedStyle(document.body).backgroundColor === 'rgb(26, 26, 26)' && !document.querySelector('#jfStyleEl')?.textContent.includes('@media (prefers-color-scheme: dark)')")
            })
        } catch {check("setup-or-load",false,error.localizedDescription)}
        await host.remove(id)
        return results
    }
}
