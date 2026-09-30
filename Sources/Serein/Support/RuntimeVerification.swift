import AppKit
import WebKit
import SereinCore

/// Deterministic integration scenarios in the actual application process.
/// These exercise the same state and WebKit objects as the UI, not AX input coverage.
@MainActor enum RuntimeVerification {
    struct Result: Codable {var name:String;var passed:Bool;var detail:String}
    static func run(manager: BrowserManager,root: URL) async {
        var results:[Result]=[]
        func check(_ name:String,_ passed:Bool,_ detail:String="") {results.append(Result(name:name,passed:passed,detail:detail));print("VERIFY \(name): \(passed ? "PASS" : "FAIL") \(detail)")}
        func pause(_ ms:Int=500) async {try? await Task.sleep(for:.milliseconds(ms))}
        func wait(_ condition:@MainActor ()->Bool) async -> Bool {
            for _ in 0..<100 {if condition(){return true};await pause(100)}
            return false
        }
        func capture(_ name:String) async {
            await pause(500)
            // The runner owns screen-capture permission. Request capture from the
            // external harness; the application itself does not need that permission.
            do {
                try name.write(to:root.appendingPathComponent("capture-request"),atomically:true,encoding:.utf8)
                var succeeded=false
                for _ in 0..<400 {
                    if FileManager.default.fileExists(atPath:root.appendingPathComponent(name+".capture-finished").path){succeeded=FileManager.default.fileExists(atPath:root.appendingPathComponent(name+".png").path);break}
                    await pause(100)
                }
                check("capture-"+name,succeeded)
            } catch {check("capture-"+name,false,error.localizedDescription)}
        }
        func keyboard(_ name:String) async -> Bool {
            do {
                let finished=root.appendingPathComponent(name+".keyboard-finished")
                if FileManager.default.fileExists(atPath:finished.path){try FileManager.default.removeItem(at:finished)}
                try name.write(to:root.appendingPathComponent("keyboard-request"),atomically:true,encoding:.utf8)
                for _ in 0..<100 {
                    if FileManager.default.fileExists(atPath:root.appendingPathComponent(name+".keyboard-finished").path){await pause(300);return true}
                    await pause(100)
                }
            } catch {print(error)}
            return false
        }
        guard let session=manager.active else{return}
        session.window?.setFrame(NSRect(x:10,y:61,width:1000,height:677),display:true)
        let fixture="http://127.0.0.1:8765/index.html"
        let start=ContinuousClock.now
        session.navigate(fixture)
        check("navigation",await wait{session.current?.webView.title=="Field Notes"},session.current?.webView.url?.absoluteString ?? "no URL")
        check("load-finished",await wait{session.current?.isLoading==false})
        do {
            let value=try await session.current!.webView.evaluateJavaScript("JSON.stringify({body:document.body.innerText,rect:document.body.getBoundingClientRect().toJSON(),width:innerWidth,height:innerHeight,scrollY:scrollY,color:getComputedStyle(document.body).color,visibility:document.visibilityState})")
            check("document-content",(value as? String)?.contains("A little room to think.")==true,String(describing:value))
            let view=session.current!.webView
            print("WEBVIEW frame=\(view.frame) bounds=\(view.bounds) window=\(String(describing:view.window)) hidden=\(view.isHidden) alpha=\(view.alphaValue)")
            let snapshot=try await withCheckedThrowingContinuation { (continuation:CheckedContinuation<NSImage,Error>) in
                view.takeSnapshot(with:nil) { image,error in
                    if let image {continuation.resume(returning:image)}
                    else {continuation.resume(throwing:error ?? NSError(domain:"Snapshot",code:1))}
                }
            }
            if let data=snapshot.tiffRepresentation,let rep=NSBitmapImageRep(data:data),let png=rep.representation(using:.png,properties:[:]) {try png.write(to:root.appendingPathComponent("diagnostic-webkit-snapshot.png"))}
        } catch {check("document-content",false,error.localizedDescription)}
        let elapsed=start.duration(to:.now)
        check("startup-fixture-timing",true,String(describing:elapsed))
        let originalTab=session.state.selectedTabID
        let initialTabCount=session.state.tabs.count
        let focused=await keyboard("address")
        check("keyboard-command-l",focused && session.window?.firstResponder is NSTextView)
        let created=await keyboard("new-tab")
        check("keyboard-command-t",created && session.state.tabs.count==initialTabCount+1)
        let closed=await keyboard("close-tab")
        check("keyboard-command-w",closed && session.state.tabs.count==initialTabCount)
        if let originalTab {session.select(originalTab)}
        let suggestionURL="http://127.0.0.1:8765/second.html?keyboard-suggestion=1"
        manager.library.bookmark(title:"Serein keyboard suggestion fixture",url:suggestionURL)
        let typedSuggestion=await keyboard("suggestion-query")
        let selectedSuggestion=await keyboard("suggestion-down")
        await capture("24-address-keyboard-suggestion")
        let movedUp=await keyboard("suggestion-up")
        check("keyboard-suggestion-keeps-typed-query",movedUp && session.address=="serein keyboard suggestion" && session.window?.firstResponder is NSTextView)
        _=await keyboard("suggestion-down")
        let escapedSuggestion=await keyboard("suggestion-escape")
        check("keyboard-suggestion-escape-keeps-editor",escapedSuggestion && session.address=="serein keyboard suggestion" && session.window?.firstResponder is NSTextView)
        _=await keyboard("suggestion-down")
        let submittedSuggestion=await keyboard("suggestion-return")
        let suggestionArrived=await wait{session.current?.webView.url?.absoluteString==suggestionURL}
        check("keyboard-address-suggestion",typedSuggestion && selectedSuggestion && submittedSuggestion && suggestionArrived,session.address)
        let contentFocused=await wait{
            guard let view=session.current?.loadedWebView,let responder=session.window?.firstResponder as? NSView else{return false}
            return responder === view || responder.isDescendant(of:view)
        }
        check("keyboard-address-submit-focuses-content",contentFocused)
        if let bookmark=manager.library.bookmarks.first(where:{$0.url==suggestionURL}) {manager.library.removeBookmark(bookmark.id)}
        session.navigate(fixture,ask:false);_=await wait{session.current?.webView.title=="Field Notes"}
        session.addressFocused=false;session.window?.makeFirstResponder(session.current?.webView)
        UserDefaults.standard.set("light",forKey:"appearance");await capture("01-light-expanded")
        let diagnosticWindow=NSWindow(contentRect:NSRect(x:80,y:90,width:800,height:580),styleMask:[.titled,.closable],backing:.buffered,defer:false)
        diagnosticWindow.title="WebKit direct AppKit diagnostic"
        let diagnosticView=WKWebView(frame:NSRect(x:0,y:0,width:800,height:580))
        diagnosticWindow.contentView=diagnosticView;diagnosticWindow.makeKeyAndOrderFront(nil)
        diagnosticView.load(URLRequest(url:URL(string:fixture)!))
        _=await wait{diagnosticView.title=="Field Notes"}
        await capture("diagnostic-direct-appkit")
        diagnosticWindow.orderOut(nil);session.window?.makeKeyAndOrderFront(nil)
        UserDefaults.standard.set("dark",forKey:"appearance");await capture("02-dark-expanded")
        UserDefaults.standard.set("light",forKey:"appearance")
        let first=session.state.selectedTabID!
        session.setKind(first,.essential)
        let second=session.newTab(url:"http://127.0.0.1:8765/second.html")
        check("second-navigation",await wait{session.current?.webView.title=="Second Field Note"})
        await capture("03-essentials")
        session.setKind(second,.pinned);let third=session.newTab(url:fixture)
        _=await wait{session.current?.webView.title=="Field Notes"};await capture("04-pinned-and-normal")
        session.addressFocused=true;session.address="unfinished search"
        _=session.setHighlighted(second,true)
        check("highlight-preserves-address-draft",session.addressFocused && session.address=="unfinished search" && session.state.selectedTabID==third)
        session.select(third)
        session.clickTab(second,modifiers:.command)
        check("command-tab-multiselection",session.tabSelection.ids == Set([second,third]) && session.state.selectedTabID==third)
        await capture("20-tab-multiselection")
        let pinnedHome=session.state.tabs.first{$0.id==second}?.homeURL
        session.setHighlightedKind(.pinned)
        check("bulk-pin-keeps-selection-and-home",session.tabSelection.ids==Set([second,third]) && session.state.selectedTabID==third && session.state.tabs.filter{[second,third].contains($0.id)}.allSatisfy{$0.kind == .pinned} && session.state.tabs.first{$0.id==second}?.homeURL==pinnedHome)
        await capture("26-bulk-pinned-selection")
        session.setHighlightedKind(.regular)
        check("bulk-unpin-keeps-selection",session.tabSelection.ids==Set([second,third]) && session.state.tabs.filter{[second,third].contains($0.id)}.allSatisfy{$0.kind == .regular && $0.homeURL==nil})
        session.setKind(second,.pinned)
        session.clickTab(first,modifiers:.shift)
        check("shift-tab-range-selection",session.tabSelection.ids == Set([first,second]) && session.state.selectedTabID==first)
        session.select(third)
        let closeA=session.newTab(),closeB=session.newTab()
        session.clickTab(closeA,modifiers:.command);session.closeHighlighted()
        check("close-highlighted-tabs",!session.state.tabs.contains{$0.id==closeA || $0.id==closeB} && session.tabSelection.ids.isSubset(of:Set(session.state.tabs.map(\.id))))
        session.select(third)
        session.addressFocused=true;await capture("05-address-focused");session.addressFocused=false
        session.addWorkspace(name:"Research")
        session.navigate(fixture);_=await wait{session.current?.webView.title=="Field Notes"};await capture("06-workspace")
        let normalWorkspace=session.state.tabs.first{$0.id==third}!.workspaceID
        let moved=session.newTab(url:"http://127.0.0.1:8765/second.html")
        session.moveTabToWorkspace(moved,normalWorkspace)
        check("workspace-move-updates-address",session.state.selectedTabID != moved && session.address == (session.state.selectedTab?.url == "about:blank" ? "" : session.state.selectedTab?.url))
        let temporary=session.addWorkspace(name:"Temporary verification workspace")
        let bulkA=session.newTab(),bulkB=session.newTab()
        session.clickTab(bulkA,modifiers:.command)
        session.moveHighlightedToWorkspace(temporary)
        check("bulk-workspace-noop-keeps-selection",session.tabSelection.ids==Set([bulkA,bulkB]) && session.state.selectedTabID==bulkB)
        session.moveHighlightedToWorkspace(normalWorkspace)
        check("bulk-workspace-move-snapshots-selection",session.state.tabs.filter{[bulkA,bulkB].contains($0.id) && $0.workspaceID==normalWorkspace}.count==2 && session.state.selectedTabID != bulkA && session.state.selectedTabID != bulkB && session.tabSelection.ids==Set(session.state.selectedTabID.map{[$0]} ?? []))
        session.close(bulkA,ask:false);session.close(bulkB,ask:false)
        session.removeWorkspace(temporary)
        check("workspace-removal-updates-selection",!session.state.workspaces.contains{$0.id==temporary} && session.current?.id == session.state.selectedTabID && session.address == (session.state.selectedTab?.url == "about:blank" ? "" : session.state.selectedTab?.url))
        session.close(moved,ask:false)
        session.switchWorkspace(normalWorkspace);session.select(third);session.state.split(with:second)
        await capture("07-split")
        session.select(second)
        check("split-secondary-focus-keeps-panes",session.state.primarySplitTabID==third && session.state.secondaryTabID==second && session.state.selectedTabID==second)
        await capture("07-split-secondary-focused")
        let visiblePrimary=session.runtimes[third]
        session.unload(third)
        check("split-primary-cannot-unload",visiblePrimary != nil && session.window?.attachedSheet == nil && session.runtimes[third] === visiblePrimary)

        session.select(third);session.state.secondaryTabID=nil;session.state.primarySplitTabID=nil
        session.state.sidebar = .compact;session.compactRevealed=false;await capture("08-compact-hidden")
        session.compactRevealed=true;await capture("09-compact-revealed")
        session.state.sidebar = .collapsed;await capture("10-collapsed")
        let inactive=session.newTab(url:fixture,select:false)
        let inactiveRuntime=session.runtime(inactive)
        _=inactiveRuntime.webView
        session.unload(inactive)
        let unloadSheet=session.window?.attachedSheet
        check("inactive-unload-prompts",unloadSheet != nil)
        session.select(inactive)
        if let unloadSheet {session.window?.endSheet(unloadSheet,returnCode:.alertFirstButtonReturn)}
        try? await Task.sleep(for:.milliseconds(100))
        check("unload-revalidates-selection",session.runtimes[inactive] === inactiveRuntime)
        session.select(third)
        _=await wait{!inactiveRuntime.isLoading}
        session.unload(inactive)
        let staleUnloadSheet=session.window?.attachedSheet
        inactiveRuntime.load(URL(string:fixture+"?replacement-before-unload")!)
        if let staleUnloadSheet {session.window?.endSheet(staleUnloadSheet,returnCode:.alertFirstButtonReturn)}
        await pause(200)
        check("unload-preserves-new-document",staleUnloadSheet != nil && session.runtimes[inactive] === inactiveRuntime)
        session.close(inactive,ask:false)

        session.select(third)
        if let edited=session.current {
            _=try? await edited.webView.evaluateJavaScript("document.querySelector('input')?.dispatchEvent(new Event('input',{bubbles:true}))")
            check("navigation-edit-detected",await wait{edited.hasUserEdits})
            session.navigate("http://127.0.0.1:8765/second.html?stale-confirmation")
            let sheet=session.window?.attachedSheet
            check("navigation-edited-page-prompts",sheet != nil)
            session.select(second)
            if let sheet {session.window?.endSheet(sheet,returnCode:.alertFirstButtonReturn)}
            await pause(300)
            check("navigation-confirmation-keeps-new-tab",session.state.selectedTabID==second && !(session.current?.webView.url?.absoluteString.contains("stale-confirmation") ?? true))
            session.select(third)
            session.navigate("http://127.0.0.1:8765/second.html?stale-document")
            let documentSheet=session.window?.attachedSheet
            edited.load(URL(string:fixture+"?fresh-document")!)
            if let documentSheet {session.window?.endSheet(documentSheet,returnCode:.alertFirstButtonReturn)}
            _=await wait{edited.webView.url?.query=="fresh-document" && !edited.isLoading}
            check("navigation-confirmation-keeps-new-document",documentSheet != nil && edited.webView.url?.query=="fresh-document")
        }

        let closing=session.newTab(url:fixture)
        let closingRuntime=session.runtime(closing)
        _=await wait{closingRuntime.webView.title=="Field Notes" && !closingRuntime.isLoading}
        closingRuntime.hasUserEdits=true
        var closeResult:Bool?
        session.close(closing){closeResult=$0}
        let closeSheet=session.window?.attachedSheet
        check("edited-close-waits-for-consent",closeSheet != nil && closeResult==nil)
        await capture("27-edited-close-confirmation")
        closingRuntime.load(URL(string:fixture+"?replacement-before-close")!)
        if let closeSheet {session.window?.endSheet(closeSheet,returnCode:.alertFirstButtonReturn)}
        _=await wait{closeResult != nil}
        check("edited-close-preserves-new-document",closeResult==false && session.state.tabs.contains{$0.id==closing})
        _=await wait{!closingRuntime.isLoading}
        closingRuntime.hasUserEdits=true;closeResult=nil
        session.close(closing){closeResult=$0}
        if let sheet=session.window?.attachedSheet {session.window?.endSheet(sheet,returnCode:.alertSecondButtonReturn)}
        _=await wait{closeResult != nil}
        check("edited-close-cancel-reports-failure",closeResult==false && session.state.tabs.contains{$0.id==closing})
        let closeCompanion=session.newTab()
        session.clickTab(closing,modifiers:.command)
        session.closeHighlighted()
        let bulkCloseSheet=session.window?.attachedSheet
        closingRuntime.load(URL(string:fixture+"?replacement-before-bulk-close")!)
        if let bulkCloseSheet {session.window?.endSheet(bulkCloseSheet,returnCode:.alertFirstButtonReturn)}
        await pause(200)
        check("bulk-close-preserves-replacement-document",bulkCloseSheet != nil && session.state.tabs.filter{[closing,closeCompanion].contains($0.id)}.count==2)
        session.close(closeCompanion,ask:false)
        closeResult=nil
        session.close(closing,ask:false){closeResult=$0}
        check("close-completion-follows-removal",closeResult==true && !session.state.tabs.contains{$0.id==closing})
        session.select(third)
        session.state.sidebar = .expanded;session.libraryPanel = .settings;await capture("11-settings");session.libraryPanel=nil
        session.findVisible=true;session.findText="Workspace";session.find();await capture("12-find");session.findVisible=false
        let unavailable="http://127.0.0.1:19876/unavailable"
        session.navigate(unavailable)
        check("navigation-error",await wait{session.current?.failure != nil})
        check("navigation-error-keeps-destination",session.address==unavailable && session.state.selectedTab?.url==unavailable)
        session.current?.reload()
        check("navigation-error-retry-keeps-destination",await wait{session.current?.failure != nil && session.current?.failedURL?.absoluteString==unavailable})
        await capture("13-network-error")
        session.navigate(fixture);check("navigation-recovery",await wait{session.current?.webView.title=="Field Notes" && session.current?.failure==nil})
        do {
            _=try await session.current!.webView.evaluateJavaScript("document.cookie='sereinPrivateCheck=normal;path=/'")
            let normalCookies=await session.dataStore.httpCookieStore.allCookies()
            check("normal-cookie",normalCookies.contains{$0.name=="sereinPrivateCheck"})
            let privateSession=manager.newWindow(isPrivate:true);privateSession.navigate(fixture)
            _=await wait{privateSession.current?.webView.title=="Field Notes"}
            let privateCookies=await privateSession.dataStore.httpCookieStore.allCookies()
            check("private-cookie-isolation",!privateCookies.contains{$0.name=="sereinPrivateCheck"} && !privateSession.dataStore.isPersistent)
            check("private-extension-isolation",privateSession.extensions==nil && privateSession.current?.webView.configuration.webExtensionController==nil)
            manager.saveNow()
            let saved=try SavedSession.decode(Data(contentsOf:root.appendingPathComponent("session.json")))
            check("private-session-exclusion",!saved.windows.contains{$0.isPrivate} && !saved.windows.contains{$0.id==privateSession.state.id})
            privateSession.window?.performClose(nil)
        } catch {check("private-cookie-isolation",false,error.localizedDescription)}
        session.window?.makeKeyAndOrderFront(nil)
        results += LibraryVerification.run(root: root)
        results += await DownloadVerification.run(manager:manager,session:session,root:root)
        // Exercise the actual permission stores used by delegate decisions and settings.
        let permissionOrigin=SiteOrigin(url:URL(string:fixture)!)!
        let permissionKey=SitePermissionKey(topLevel:permissionOrigin,requesting:permissionOrigin,capability:.camera)
        session.sitePermissions.set(.deny,for:[permissionKey])
        let reloadedPermissions=SitePermissionStore(file:root.appendingPathComponent("site-permissions.json"))
        check("site-permission-persistence",reloadedPermissions.policy.decision(for:[permissionKey]) == .deny)
        let permissionPrivate=manager.newWindow(isPrivate:true)
        check("private-permission-normal-isolation",permissionPrivate.sitePermissions.policy.decision(for:[permissionKey]) == .ask)
        permissionPrivate.sitePermissions.set(.allow,for:[permissionKey])
        let otherPrivate=manager.newWindow(isPrivate:true)
        check("private-permission-window-isolation",otherPrivate.sitePermissions.policy.decision(for:[permissionKey]) == .ask)
        check("private-permission-no-disk-write",SitePermissionStore(file:root.appendingPathComponent("site-permissions.json")).policy.decision(for:[permissionKey]) == .deny)
        permissionPrivate.window?.performClose(nil);otherPrivate.window?.performClose(nil)
        session.sitePermissions.reset()
        check("site-permission-reset-persists",SitePermissionStore(file:root.appendingPathComponent("site-permissions.json")).policy.records.isEmpty)
        session.window?.makeKeyAndOrderFront(nil)
        let count=session.state.tabs.count;session.close(third,ask:false);session.reopen()
        check("close-reopen",session.state.tabs.count==count && session.state.selectedTab?.url==fixture)
        var switchSamples:[Double]=[]
        for _ in 0..<10 {
            let t=ContinuousClock.now;session.select(first);await pause(16);session.select(second);await pause(16)
            let d=t.duration(to:.now).components;switchSamples.append(Double(d.seconds)*1000+Double(d.attoseconds)/1e15)
        }
        check("tab-switch-samples",true,"Two switches including two 16ms yields, milliseconds: \(switchSamples)")
        session.select(first);session.state.sidebar = .expanded
        await capture("14-restored")
        let idleMetadata:[String:Any] = ["tabs":session.state.tabs.count,"visibleTabs":session.state.visibleTabs.count,"secondsRequested":12,"page":fixture,"note":"Warm idle after integration scenarios; renderer failure prevents normal visual-workload claims."]
        try? JSONSerialization.data(withJSONObject:idleMetadata,options:.prettyPrinted).write(to:root.appendingPathComponent("idle-workload.json"))
        try? Data().write(to:root.appendingPathComponent("idle-start"))
        await pause(12_000)
        try? Data().write(to:root.appendingPathComponent("idle-end"))
        results += await WindowConsentVerification.run(manager:manager)
        session.window?.makeKeyAndOrderFront(nil)
        results += await SitePermissionVerification.run(session:session,root:root)
        results += await ExtensionVerification.run(manager:manager,session:session,root:root)
        ExtensionSelectionTrace.save(to:root)
        await RealExtensionAudit.run(manager:manager,root:root)
        do {try JSONEncoder().encode(results).write(to:root.appendingPathComponent("results.json"),options:.atomic)} catch {print(error)}
        manager.saveNow()
        print("VERIFICATION_COMPLETE \(results.filter{!$0.passed}.count) failures")
        fflush(stdout)
        NSApp.terminate(nil)
    }
}
