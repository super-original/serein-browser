import Foundation
import WebKit
import SereinCore

/// Load-only compatibility audit. A loaded package is NOT marked compatible.
@MainActor enum RealExtensionAudit {
    struct Candidate:Codable {var name:String;var version:String;var url:String;var sha256:String;var path:String?;var fetchError:String?}
    struct Result:Codable {var candidate:Candidate;var status:String;var detail:String;var semanticScenariosVerified:Bool=false;var capabilities:Capabilities?=nil}
    struct Capabilities:Codable {
        let originalManifestSHA256:String
        let installedManifestSHA256:String
        let normalized:Bool
        let requiredPermissions:[String]
        let requiredHosts:[String]
        let optionalPermissions:[String]
        let optionalHosts:[String]
        var recognizedRequired:[String]=[]
        var recognizedOptional:[String]=[]
        init(_ ledger:ExtensionCapabilityLedger) {
            originalManifestSHA256=ledger.originalSHA256;installedManifestSHA256=ledger.installedSHA256;normalized=ledger.manifestWasNormalized
            requiredPermissions=ledger.requiredPermissions;requiredHosts=ledger.requiredHosts
            optionalPermissions=ledger.optionalPermissions;optionalHosts=ledger.optionalHosts
        }
    }
    static func run(manager:BrowserManager,root:URL) async {
        let args=ProcessInfo.processInfo.arguments
        guard let i=args.firstIndex(of:"--real-extension-catalog"),args.indices.contains(i+1) else{return}
        var results:[Result]=[]
        // Third-party files must remain outside uploaded evidence even if WebKit
        // stalls or crashes before this audit reaches its ordinary cleanup.
        let temporary=FileManager.default.temporaryDirectory.appendingPathComponent("serein-real-audit-"+UUID().uuidString)
        defer{try? FileManager.default.removeItem(at:temporary)}
        do {
            try PrivateFileStore.prepareDirectory(temporary)
            let candidates=try JSONDecoder().decode([Candidate].self,from:Data(contentsOf:URL(fileURLWithPath:args[i+1])))
            for candidate in candidates {
                guard let path=candidate.path else{results.append(.init(candidate:candidate,status:"source-unavailable",detail:candidate.fetchError ?? "No file"));continue}
                let host=manager.extensions,id=UUID(),target=temporary.appendingPathComponent(id.uuidString)
                AppMemoryProbe.record("audit-before-prepare:"+candidate.name)
                var capabilities:Capabilities?
                do {
                    let prepared=try host.preparePackage(URL(fileURLWithPath:path),at:target)
                    capabilities=Capabilities(prepared.ledger)
                    AppMemoryProbe.record("audit-after-prepare:"+candidate.name)
                    let manifest=try ExtensionManifest(data:Data(contentsOf:target.appendingPathComponent("manifest.json")))
                    let ext=try await WKWebExtension(resourceBaseURL:target)
                    AppMemoryProbe.record("audit-after-webkit-load:"+candidate.name)
                    capabilities?.recognizedRequired=ext.requestedPermissions.map(\.rawValue).sorted()
                    capabilities?.recognizedOptional=ext.optionalPermissions.map(\.rawValue).sorted()
                    let errors=ext.errors.map(\.localizedDescription)
                    if !errors.isEmpty {results.append(.init(candidate:candidate,status:"webkit-validation-rejected",detail:errors.joined(separator:"\n")))}
                    else {
                        try manifest.validateRequiredPermissions(recognized:Set(ext.requestedPermissions.map(\.rawValue)))
                        let context=WKWebExtensionContext(for:ext);context.uniqueIdentifier=id.uuidString;context.hasAccessToPrivateData=false
                        try host.controller.load(context)
                        try await Task.sleep(for:.milliseconds(300))
                        results.append(.init(candidate:candidate,status:"loaded-without-permission-grants",detail:"Public WebKit accepted the context. No functional compatibility claimed. Requested: \(ext.requestedPermissions.map(\.rawValue).sorted().joined(separator:", "))"))
                        try host.controller.unload(context)
                        let persistentTypes=WKWebExtensionController.allExtensionDataTypes.subtracting([.session])
                        let records=await host.controller.dataRecords(ofTypes:persistentTypes)
                        await host.controller.removeData(ofTypes:persistentTypes,from:records.filter{$0.uniqueIdentifier==id.uuidString})
                    }
                } catch {results.append(.init(candidate:candidate,status:"installation-rejected",detail:error.localizedDescription))}
                if let index=results.indices.last {results[index].capabilities=capabilities}
                try? FileManager.default.removeItem(at:target)
                try? await Task.sleep(for:.milliseconds(50))
                AppMemoryProbe.record("audit-after-release:"+candidate.name)
            }
            try JSONEncoder().encode(results).write(to:root.appendingPathComponent("real-extension-results.json"),options:.atomic)
            for result in results {print("REAL_EXTENSION \(result.candidate.name): \(result.status) \(result.detail)")}
        } catch {print("REAL_EXTENSION_AUDIT_ERROR \(error)")}
    }
}
