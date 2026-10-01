import AppKit
import WebKit
import SereinCore

/// Isolate custom resource origins from the ordinary browser verification process.
@MainActor enum ExtensionOriginVerification {
    static func run(manager:BrowserManager,root:URL) async->[RuntimeVerification.Result] {
        var results:[RuntimeVerification.Result]=[]
        func stage(_ name:String) {
            print("ORIGIN_STAGE \(name)");fflush(stdout)
            try? name.write(to:root.appendingPathComponent("stage.txt"),atomically:true,encoding:.utf8)
        }
        func check(_ name:String,_ pass:Bool,_ detail:String="") {
            results.append(.init(name:name,passed:pass,detail:detail))
            try? JSONEncoder().encode(results).write(to:root.appendingPathComponent("partial-results.json"),options:.atomic)
        }
        let host=manager.extensions,id=UUID()
        do {
            stage("prepare")
            let source=Bundle.main.resourceURL!.appendingPathComponent("Fixtures/Extensions/mv2")
            try host.prepare(source,at:host.root.appendingPathComponent(id.uuidString))
            check("custom-scheme-not-built-in",!WKWebView.handlesURLScheme("moz-extension"))
            let record=InstalledExtension(id:id,name:"Firefox origin probe",version:"1.0",enabled:true,permissions:["storage","tabs"],hosts:[],resourceBaseURL:ExtensionResourceOrigin.initialURL(sourceExtension:"xpi",id:id))
            host.records.append(record)
            stage("load-custom-origin")
            try await host.load(record)
            guard let context=host.contexts[id],let session=manager.active else{throw ExtensionValidationError.invalid("Missing probe context/window")}
            check("custom-origin-retained",context.baseURL.scheme=="moz-extension")
            stage("load-resource")
            let url=context.baseURL.appendingPathComponent("popup.html")
            let tab=session.newTab(url:url.absoluteString),view=session.runtime(tab).webView
            for _ in 0..<100 {if view.url==url && !view.isLoading{break};try? await Task.sleep(for:.milliseconds(50))}
            let scheme=try? await view.evaluateJavaScript("browser.runtime.getURL('').split(':')[0]") as? String
            check("resource-runtime-url",scheme=="moz-extension",String(describing:scheme))
            stage("background")
            let failure=await ExtensionBackgroundProbe.failure(for:context)
            check("background-load-completes",failure==nil,failure ?? "")
            stage("capture")
            try? "resource-page".write(to:root.appendingPathComponent("capture-request"),atomically:true,encoding:.utf8)
            for _ in 0..<50 {if FileManager.default.fileExists(atPath:root.appendingPathComponent("resource-page.capture-finished").path){break};try? await Task.sleep(for:.milliseconds(100))}
            check("resource-desktop-captured",FileManager.default.fileExists(atPath:root.appendingPathComponent("resource-page.png").path))
            stage("remove")
            session.close(tab,ask:false)
            await host.remove(id)
            check("context-removed",host.contexts[id]==nil)
            stage("done")
        } catch{check("setup",false,error.localizedDescription);stage("failed")}
        return results
    }
}
