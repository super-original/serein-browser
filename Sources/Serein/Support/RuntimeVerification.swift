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
                let succeeded=await wait{FileManager.default.fileExists(atPath:root.appendingPathComponent(name+".png").path)}
                check("capture-"+name,succeeded)
            } catch {check("capture-"+name,false,error.localizedDescription)}
        }
        guard let session=manager.active else{return}
        session.window?.setFrame(NSRect(x:10,y:51,width:1000,height:677),display:true)
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
            let snapshot=try await view.takeSnapshot(with:nil)
            if let data=snapshot.tiffRepresentation,let rep=NSBitmapImageRep(data:data),let png=rep.representation(using:.png,properties:[:]) {try png.write(to:root.appendingPathComponent("diagnostic-webkit-snapshot.png"))}
        } catch {check("document-content",false,error.localizedDescription)}
        let elapsed=start.duration(to:.now)
        check("startup-fixture-timing",true,String(describing:elapsed))
        UserDefaults.standard.set("light",forKey:"appearance");await capture("01-light-expanded")
        UserDefaults.standard.set("dark",forKey:"appearance");await capture("02-dark-expanded")
        UserDefaults.standard.set("light",forKey:"appearance")
        let first=session.state.selectedTabID!
        session.setKind(first,.essential)
        let second=session.newTab(url:"http://127.0.0.1:8765/second.html")
        check("second-navigation",await wait{session.current?.webView.title=="Second Field Note"})
        await capture("03-essentials")
        session.setKind(second,.pinned);let third=session.newTab(url:fixture)
        _=await wait{session.current?.webView.title=="Field Notes"};await capture("04-pinned-and-normal")
        session.addressFocused=true;await capture("05-address-focused");session.addressFocused=false
        let workspace=session.state.addWorkspace(name:"Research");session.switchWorkspace(workspace)
        session.navigate(fixture);_=await wait{session.current?.webView.title=="Field Notes"};await capture("06-workspace")
        let normalWorkspace=session.state.tabs.first{$0.id==third}!.workspaceID
        session.switchWorkspace(normalWorkspace);session.select(third);session.state.split(with:second)
        await capture("07-split");session.state.secondaryTabID=nil
        session.state.sidebar = .compact;session.compactRevealed=false;await capture("08-compact-hidden")
        session.compactRevealed=true;await capture("09-compact-revealed")
        session.state.sidebar = .collapsed;await capture("10-collapsed")
        session.state.sidebar = .expanded;session.libraryPanel = .settings;await capture("11-settings");session.libraryPanel=nil
        session.findVisible=true;session.findText="Workspace";session.find();await capture("12-find");session.findVisible=false
        session.navigate("http://127.0.0.1:19876/unavailable")
        check("navigation-error",await wait{session.current?.failure != nil});await capture("13-network-error")
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
        results += await ExtensionVerification.run(manager:manager,session:session)
        do {try JSONEncoder().encode(results).write(to:root.appendingPathComponent("results.json"),options:.atomic)} catch {print(error)}
        manager.saveNow()
        print("VERIFICATION_COMPLETE \(results.filter{!$0.passed}.count) failures")
        fflush(stdout)
        NSApp.terminate(nil)
    }
}
