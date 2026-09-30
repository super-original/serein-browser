import AppKit
import WebKit
import SereinCore

@MainActor enum ExtensionUpdateVerification {
    static func run(id: UUID, host: ExtensionHost, session: BrowserSession, root: URL) async -> [RuntimeVerification.Result] {
        var results: [RuntimeVerification.Result] = []
        func check(_ name: String, _ passed: Bool, _ detail: String = "") { results.append(.init(name: "signed-update-" + name, passed: passed, detail: detail)) }
        let fixtures = Bundle.main.resourceURL!.appendingPathComponent("Fixtures/Packages")
        func apply(_ name: String, accept: Bool, capture: String? = nil) async throws -> Bool {
            let task = Task { await host.update(id, from: fixtures.appendingPathComponent(name), in: session) }
            for _ in 0..<100 {
                if session.dialogWindow?.attachedSheet != nil { break }
                try await Task.sleep(for: .milliseconds(100))
            }
            let owner = session.dialogWindow, sheet = owner?.attachedSheet
            check("consent-" + name + (accept ? "-accept" : "-cancel"), sheet != nil)
            if let sheet {
                if let capture {
                    try capture.write(to: root.appendingPathComponent("capture-request"), atomically: true, encoding: .utf8)
                    for _ in 0..<100 {
                        if FileManager.default.fileExists(atPath: root.appendingPathComponent(capture + ".capture-finished").path) { break }
                        try await Task.sleep(for: .milliseconds(100))
                    }
                    check("capture-" + capture, FileManager.default.fileExists(atPath: root.appendingPathComponent(capture + ".png").path))
                }
                owner?.endSheet(sheet, returnCode: accept ? .alertFirstButtonReturn : .alertSecondButtonReturn)
            }
            return await task.value
        }
        func state(version: String) async throws -> Bool {
            session.navigate("http://127.0.0.1:8765/index.html?extension=crx-" + version, ask: false)
            for _ in 0..<50 {
                try await Task.sleep(for: .milliseconds(100))
                if let value = try? await session.current?.webView.evaluateJavaScript("document.documentElement.dataset.sereinCRXState || null"),
                   let text = value as? String, let data = text.data(using: .utf8),
                   let payload = try JSONSerialization.jsonObject(with: data) as? [String:String], payload["version"] == version {
                    return payload["marker"] == "preserved-across-update"
                }
            }
            return false
        }
        do {
            guard let before = host.records.first(where: { $0.id == id }), let originalContext = host.contexts[id] else { throw ExtensionValidationError.invalid("Signed fixture is not installed") }
            var previousRequests = before; previousRequests.permissions = []; previousRequests.hosts = []
            let expired = ExtensionPermissionState(granted: [:], denied: ["storage": .distantPast], grantedHosts: [:], deniedHosts: ["http://127.0.0.1/*": .distantPast])
            let merged = try expired.updating(from: previousRequests, to: originalContext.webExtension)
            check("expired-denials-do-not-block-reviewed-grants", merged.denied.isEmpty && merged.deniedHosts.isEmpty && merged.granted["storage"] != nil && !merged.grantedHosts.isEmpty)
            let broad = try WKWebExtension.MatchPattern(string: "*://*/*")
            let narrow = try WKWebExtension.MatchPattern(string: "https://example.test/*")
            check("host-scope-containment", broad.matches(narrow) && !narrow.matches(broad))
            session.libraryPanel = .extensions
            try await Task.sleep(for: .milliseconds(500))
            host.chooseUpdate(id, in: session)
            for _ in 0..<50 {
                if session.dialogWindow?.attachedSheet is NSOpenPanel { break }
                try await Task.sleep(for: .milliseconds(100))
            }
            let chooser = session.dialogWindow?.attachedSheet as? NSOpenPanel
            check("native-update-chooser", chooser != nil)
            chooser?.cancel(nil)
            try await Task.sleep(for: .milliseconds(300))
            check("chooser-cancel-keeps-package", host.records.first(where: { $0.id == id })?.version == "1.0")
            session.libraryPanel = nil
            for _ in 0..<50 {
                if session.window?.attachedSheet == nil { break }
                try await Task.sleep(for: .milliseconds(100))
            }
            for name in ["wrong-developer.crx", "signed-fixture.crx", "signed-update-unsupported.crx"] {
                let updated = await host.update(id, from: fixtures.appendingPathComponent(name), in: session)
                check("reject-" + name, !updated && host.records.first(where: { $0.id == id })?.version == "1.0" && host.contexts[id] === originalContext, host.error ?? "")
            }
            let cancelled = try await apply("signed-update.crx", accept: false)
            check("cancel-preserves-package", !cancelled && host.records.first(where: { $0.id == id })?.version == "1.0" && host.contexts[id] === originalContext)
            guard let options = originalContext.optionsPageURL else { throw ExtensionValidationError.invalid("Fixture options page unavailable") }
            let optionsTab = session.newTab(url: options.absoluteString, select: false)
            let optionsRuntime = session.runtime(optionsTab)
            _=optionsRuntime.webView
            for _ in 0..<50 {
                if optionsRuntime.webView.title == "Signed extension options" { break }
                try await Task.sleep(for: .milliseconds(100))
            }
            let initialOptions = try? await optionsRuntime.webView.evaluateJavaScript("document.body.innerText") as? String
            check("initial-options-document", initialOptions == "Version 1.0", initialOptions ?? "no document")
            let updated = try await apply("signed-update.crx", accept: true, capture: "23-signed-update-consent")
            check("new-version-loaded", updated && host.records.first(where: { $0.id == id })?.version == "1.1" && host.contexts[id] != nil, host.error ?? "")
            let preserved = try await state(version: "1.1")
            check("identity-and-storage-preserved", host.contexts[id]?.uniqueIdentifier == before.runtimeIdentifier && preserved)
            var optionText: String?
            for _ in 0..<50 {
                optionText = try? await optionsRuntime.webView.evaluateJavaScript("document.body.innerText") as? String
                if optionText == "Version 1.1" { break }
                try await Task.sleep(for: .milliseconds(100))
            }
            check("resource-origin-and-open-page-preserved", host.contexts[id]?.baseURL == originalContext.baseURL && optionText == "Version 1.1", optionText ?? "no options document")
            func waitForOptions(_ expected:String) async -> Bool {
                for _ in 0..<50 {
                    if let text=try? await optionsRuntime.webView.evaluateJavaScript("document.body.innerText") as? String,text==expected,optionsRuntime.webView.url==options,!optionsRuntime.webView.isLoading{return true}
                    try? await Task.sleep(for:.milliseconds(100))
                }
                return false
            }
            let ordinary=URL(string:"http://127.0.0.1:8765/index.html?options-history=1")!
            optionsRuntime.load(ordinary)
            for _ in 0..<50 {
                if optionsRuntime.webView.url==ordinary,!optionsRuntime.webView.isLoading{break}
                try await Task.sleep(for:.milliseconds(100))
            }
            check("options-to-ordinary-document",optionsRuntime.webView.url==ordinary && optionsRuntime.webView.title != "Signed extension options")
            let privateTarget=String(data:try JSONSerialization.data(withJSONObject:[options.absoluteString]),encoding:.utf8)!
            _=try? await optionsRuntime.webView.evaluateJavaScript("location.href="+privateTarget+"[0]")
            try await Task.sleep(for:.milliseconds(500))
            check("website-cannot-open-private-options",optionsRuntime.webView.url==ordinary)
            optionsRuntime.goBack()
            check("back-to-options-document",await waitForOptions("Version 1.1"))
            optionsRuntime.goForward()
            for _ in 0..<50 {
                if optionsRuntime.webView.url==ordinary,!optionsRuntime.webView.isLoading{break}
                try await Task.sleep(for:.milliseconds(100))
            }
            check("forward-to-ordinary-document",optionsRuntime.webView.url==ordinary)
            optionsRuntime.load(options)
            check("ordinary-to-options-document",await waitForOptions("Version 1.1"))
            _=try? await optionsRuntime.webView.evaluateJavaScript("location.href='http://127.0.0.1:8765/second.html?options-link=1'")
            for _ in 0..<50 {
                if optionsRuntime.webView.url?.query=="options-link=1",!optionsRuntime.webView.isLoading{break}
                try await Task.sleep(for:.milliseconds(100))
            }
            check("page-initiated-origin-transition",optionsRuntime.webView.url?.query=="options-link=1")
            _=try? await optionsRuntime.webView.evaluateJavaScript("history.back()")
            check("script-history-back-to-options",await waitForOptions("Version 1.1"))
            check("script-history-preserves-forward",optionsRuntime.webView.canGoForward)
            check("new-permission-consented", host.contexts[id]?.hasPermission(WKWebExtension.Permission(rawValue: "tabs")) == true)
            check("old-package-cleaned-after-commit", !FileManager.default.fileExists(atPath: before.directory(in: host.root).path))
            guard let context = host.contexts[id] else { throw ExtensionValidationError.invalid("Updated context missing") }
            let site = URL(string: "http://127.0.0.1:8765/index.html")!
            context.setPermissionStatus(.unknown, for: WKWebExtension.Permission(rawValue: "tabs"))
            context.setPermissionStatus(.deniedExplicitly, for: site)
            host.rememberPermissions(context)
            await host.setEnabled(id, false)
            let restoredOptionsTab=session.newTab(url:options.absoluteString,select:false)
            let restoredOptionsRuntime=session.runtime(restoredOptionsTab)
            _=restoredOptionsRuntime.webView
            try await Task.sleep(for:.milliseconds(200))
            let disabledUpdate = try await apply("signed-update-disabled.crx", accept: true)
            check("disabled-state-preserved", disabledUpdate && host.records.first(where: { $0.id == id })?.enabled == false && host.contexts[id] == nil)
            let saved = try JSONDecoder().decode([InstalledExtension].self, from: Data(contentsOf: host.root.appendingPathComponent("extensions.json")))
            check("version-pointer-persists", saved.first(where: { $0.id == id })?.packageVersionID != nil && saved.first(where: { $0.id == id })?.version == "1.2")
            await host.setEnabled(id, true)
            guard let restored = host.contexts[id] else { throw ExtensionValidationError.invalid("Disabled update did not re-enable") }
            let refreshed=await waitForOptions("Version 1.2")
            func diagnostic(_ runtime:TabRuntime)->String {
                "url=\(String(describing:runtime.loadedWebView?.url)) saved=\(session.state.tabs.first{$0.id==runtime.id}?.url ?? "missing") title=\(runtime.title) failure=\(runtime.failure ?? "none") loading=\(runtime.isLoading) revision=\(runtime.viewRevision)"
            }
            check("open-options-refresh-after-reenable",refreshed,diagnostic(optionsRuntime))
            var restoredText:String?
            for _ in 0..<50 {
                restoredText=try? await restoredOptionsRuntime.webView.evaluateJavaScript("document.body.innerText") as? String
                if restoredText=="Version 1.2"{break}
                try await Task.sleep(for:.milliseconds(100))
            }
            check("unavailable-options-retry-after-context-load",restoredText=="Version 1.2",(restoredText ?? "no document")+" "+diagnostic(restoredOptionsRuntime))
            session.close(optionsTab,ask:false);session.close(restoredOptionsTab,ask:false)
            check("revocation-and-site-denial-preserved", !restored.hasPermission(WKWebExtension.Permission(rawValue: "tabs")) && restored.permissionStatus(for: site) == .deniedExplicitly)
            restored.setPermissionStatus(.grantedExplicitly, for: site)
            host.rememberPermissions(restored)
            check("disabled-update-data-preserved", try await state(version: "1.2"))
            let downgrade = await host.update(id, from: fixtures.appendingPathComponent("signed-fixture.crx"), in: session)
            check("downgrade-preserves-new-version", !downgrade && host.records.first(where: { $0.id == id })?.version == "1.2")
        } catch { check("scenario", false, error.localizedDescription) }
        return results
    }
}
