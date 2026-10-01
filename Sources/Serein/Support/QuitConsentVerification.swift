import AppKit

/// terminateLater runs NSModalPanelRunLoopMode, so a task awaiting its own
/// terminate call cannot answer the sheet. Drive this fixture in both modes.
@MainActor final class QuitConsentVerification:NSObject {
    let manager:BrowserManager
    let root:URL
    let session:BrowserSession
    let runtime:TabRuntime
    var timer:Timer?
    var stage=0
    var added:UUID?
    var results:[RuntimeVerification.Result]=[]
    init(manager:BrowserManager,root:URL,session:BrowserSession,runtime:TabRuntime) {
        self.manager=manager;self.root=root;self.session=session;self.runtime=runtime
    }
    static func run(manager:BrowserManager,root:URL) {
        guard let session=manager.active,let runtime=session.current else{return}
        let fixture=QuitConsentVerification(manager:manager,root:root,session:session,runtime:runtime)
        let timer=Timer(timeInterval:0.25,target:fixture,selector:#selector(tick),userInfo:nil,repeats:true)
        fixture.timer=timer
        RunLoop.main.add(timer,forMode:.default)
        RunLoop.main.add(timer,forMode:.modalPanel)
    }
    func check(_ name:String,_ passed:Bool) {
        results.append(.init(name:name,passed:passed,detail:"Actual NSApplication termination request and native sheet response"))
        try? JSONEncoder().encode(results).write(to:root.appendingPathComponent("results.json"),options:.atomic)
    }
    @objc func requestQuit(){NSApp.terminate(nil)}
    @objc func tick() {
        guard let window=session.window else{return}
        try? String(stage).write(to:root.appendingPathComponent("stage.txt"),atomically:true,encoding:.utf8)
        switch stage {
        case 0:
            runtime.hasUserEdits=true;stage=1;perform(#selector(requestQuit),with:nil,afterDelay:0)
        case 1:
            guard let sheet=window.attachedSheet else{return}
            stage=2;window.endSheet(sheet,returnCode:.alertSecondButtonReturn)
        case 2:
            guard window.attachedSheet==nil else{return}
            check("quit-cancel-keeps-app-and-edits",runtime.hasUserEdits && manager.windows.contains{$0.session===session})
            stage=3;perform(#selector(requestQuit),with:nil,afterDelay:0)
        case 3:
            guard let sheet=window.attachedSheet else{return}
            added=session.newTab(select:false)
            stage=4;window.endSheet(sheet,returnCode:.alertFirstButtonReturn)
        case 4:
            guard window.attachedSheet==nil else{return}
            check("quit-new-tab-invalidates-consent",runtime.hasUserEdits && session.state.tabs.contains{$0.id==added})
            stage=5;perform(#selector(requestQuit),with:nil,afterDelay:0)
        case 5:
            guard let sheet=window.attachedSheet else{return}
            check("quit-fresh-consent-required",true)
            // Only the isolated fixture root is obstructed. Keep its earlier file
            // as evidence, and make the atomic session rename fail deterministically.
            do {
                let file=root.appendingPathComponent("session.json")
                if FileManager.default.fileExists(atPath:file.path) {try FileManager.default.moveItem(at:file,to:root.appendingPathComponent("session-before-save-failure.json"))}
                try FileManager.default.createDirectory(at:file,withIntermediateDirectories:false)
                stage=6;window.endSheet(sheet,returnCode:.alertFirstButtonReturn)
            } catch {check("quit-storage-failure-setup",false);timer?.invalidate()}
        case 6:
            guard let error=manager.restorationError,error.hasPrefix("Session could not be saved:"),session.error==error else{return}
            check("quit-save-failure-keeps-app-and-edits",runtime.hasUserEdits && manager.windows.contains{$0.session===session})
            do {
                try FileManager.default.removeItem(at:root.appendingPathComponent("session.json"))
                stage=7;session.error=nil
            } catch {check("quit-storage-failure-repair",false);timer?.invalidate()}
        case 7:
            guard window.attachedSheet==nil else{return}
            stage=8;perform(#selector(requestQuit),with:nil,afterDelay:0)
        case 8:
            guard let sheet=window.attachedSheet else{return}
            check("quit-after-save-failure-requires-fresh-consent",runtime.hasUserEdits)
            timer?.invalidate();timer=nil;stage=9
            window.endSheet(sheet,returnCode:.alertFirstButtonReturn)
        default:break
        }
    }
}
