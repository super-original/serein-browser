import Foundation
import WebKit
import SereinCore

/// Load-only compatibility audit. A loaded package is NOT marked compatible.
@MainActor enum RealExtensionAudit {
    struct Candidate:Codable {var name:String;var version:String;var url:String;var sha256:String;var path:String?;var fetchError:String?}
    struct Result:Codable {var candidate:Candidate;var status:String;var detail:String;var semanticScenariosVerified:Bool=false}
    static func run(manager:BrowserManager,root:URL) async {
        let args=ProcessInfo.processInfo.arguments
        guard let i=args.firstIndex(of:"--real-extension-catalog"),args.indices.contains(i+1) else{return}
        var results:[Result]=[]
        do {
            let candidates=try JSONDecoder().decode([Candidate].self,from:Data(contentsOf:URL(fileURLWithPath:args[i+1])))
            for candidate in candidates {
                guard let path=candidate.path else{results.append(.init(candidate:candidate,status:"source-unavailable",detail:candidate.fetchError ?? "No file"));continue}
                let host=manager.extensions,id=UUID(),target=manager.extensions.root.appendingPathComponent(UUID().uuidString)
                do {
                    try host.prepare(URL(fileURLWithPath:path),at:target)
                    _=try ExtensionManifest(data:Data(contentsOf:target.appendingPathComponent("manifest.json")))
                    let ext=try await WKWebExtension(resourceBaseURL:target)
                    let errors=ext.errors.map(\.localizedDescription)
                    if !errors.isEmpty {results.append(.init(candidate:candidate,status:"webkit-validation-rejected",detail:errors.joined(separator:"\n")))}
                    else {
                        let context=WKWebExtensionContext(for:ext);context.uniqueIdentifier=id.uuidString;context.hasAccessToPrivateData=false
                        try host.controller.load(context)
                        try await Task.sleep(for:.milliseconds(300))
                        results.append(.init(candidate:candidate,status:"loaded-without-permission-grants",detail:"Public WebKit accepted the context. No functional compatibility claimed. Requested: \(ext.requestedPermissions.map(\.rawValue).sorted().joined(separator:", "))"))
                        try host.controller.unload(context)
                        let records=await host.controller.dataRecords(ofTypes:WKWebExtensionController.allExtensionDataTypes)
                        await host.controller.removeData(ofTypes:WKWebExtensionController.allExtensionDataTypes,from:records.filter{$0.uniqueIdentifier==id.uuidString})
                    }
                } catch {results.append(.init(candidate:candidate,status:"installation-rejected",detail:error.localizedDescription))}
                try? FileManager.default.removeItem(at:target)
            }
            try JSONEncoder().encode(results).write(to:root.appendingPathComponent("real-extension-results.json"),options:.atomic)
            for result in results {print("REAL_EXTENSION \(result.candidate.name): \(result.status) \(result.detail)")}
        } catch {print("REAL_EXTENSION_AUDIT_ERROR \(error)")}
    }
}
