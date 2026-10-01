import AppKit
import WebKit
import SereinCore

@MainActor enum ExtensionErrorVerification {
    static func run(manager:BrowserManager,root:URL) async->[RuntimeVerification.Result] {
        var results:[RuntimeVerification.Result]=[]
        func check(_ name:String,_ pass:Bool,_ detail:String=""){results.append(.init(name:"extension-runtime-error-"+name,passed:pass,detail:detail))}
        func wait(_ condition:@MainActor ()->Bool) async {for _ in 0..<100{if condition(){return};try? await Task.sleep(for:.milliseconds(50))}}
        let session=manager.newWindow(),host=manager.extensions,id=UUID()
        defer{session.libraryPanel=nil;session.window?.close()}
        do {
            let source=Bundle.main.resourceURL!.appendingPathComponent("Fixtures/ExtensionRuntimeFailure")
            try host.prepare(source,at:host.root.appendingPathComponent(id.uuidString))
            let record=InstalledExtension(id:id,name:"Background failure fixture",version:"1.0",enabled:true,permissions:[],hosts:[])
            host.records.append(record);try await host.load(record)
            guard let context=host.contexts[id] else{throw ExtensionValidationError.invalid("Missing error fixture context")}
            let failure=await ExtensionBackgroundProbe.failure(for:context)
            await wait{!(host.contextErrors[id] ?? []).isEmpty}
            check("background-failure-detected",failure != nil && !context.errors.isEmpty,failure ?? "No load error")
            check("notification-reaches-row",host.contextErrors[id] == context.errors.map(\.localizedDescription) && !(host.contextErrors[id] ?? []).isEmpty,(host.contextErrors[id] ?? []).joined(separator:"\n"))
            session.window?.makeKeyAndOrderFront(nil);session.libraryPanel = .extensions
            await wait{session.window?.attachedSheet != nil}
            try? "53-extension-runtime-error".write(to:root.appendingPathComponent("capture-request"),atomically:true,encoding:.utf8)
            await wait{FileManager.default.fileExists(atPath:root.appendingPathComponent("53-extension-runtime-error.capture-finished").path)}
            check("native-error-capture",FileManager.default.fileExists(atPath:root.appendingPathComponent("53-extension-runtime-error.png").path))
            session.libraryPanel=nil
            await wait{session.window?.attachedSheet==nil}
            await host.setEnabled(id,false)
            check("disabled-context-clears-row",host.contexts[id]==nil && host.contextErrors[id]==nil)
        } catch{check("setup",false,error.localizedDescription)}
        await host.remove(id)
        return results
    }
}
