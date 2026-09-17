import AppKit
import WebKit
import SereinCore

extension ExtensionHost: WKWebExtensionControllerDelegate {
    func webExtensionController(_ controller:WKWebExtensionController,didUpdate action:WKWebExtension.Action,forExtensionContext context:WKWebExtensionContext) {actionRevision += 1}
    func webExtensionController(_ controller: WKWebExtensionController,openWindowsFor context: WKWebExtensionContext) -> [any WKWebExtensionWindow] {
        manager?.windows.filter{!$0.session.state.isPrivate}.compactMap{$0.session.extensionWindow} ?? []
    }
    func webExtensionController(_ controller: WKWebExtensionController,focusedWindowFor context: WKWebExtensionContext) -> (any WKWebExtensionWindow)? {
        guard let session=manager?.active,!session.state.isPrivate else{return nil};return session.extensionWindow
    }
    func webExtensionController(_ controller: WKWebExtensionController,openNewTabUsing configuration: WKWebExtension.TabConfiguration,for context: WKWebExtensionContext,completionHandler: @escaping ((any WKWebExtensionTab)?,(any Error)?)->Void) {
        guard let session=(configuration.window as? ExtensionWindow)?.session ?? manager?.active,!session.state.isPrivate else{completionHandler(nil,ExtensionValidationError.invalid("No normal browsing window is available."));return}
        if let url=configuration.url,!canOpen(url,for:context) {completionHandler(nil,ExtensionValidationError.invalid("The extension may not open this URL scheme or another extension's private page."));return}
        let id=session.newTab(url:configuration.url?.absoluteString ?? "about:blank",select:configuration.shouldBeActive)
        if configuration.shouldBePinned {session.setKind(id,.pinned)}
        if configuration.index<session.state.tabs.count,let old=session.state.tabs.firstIndex(where:{$0.id==id}) {let tab=session.state.tabs.remove(at:old);session.state.tabs.insert(tab,at:configuration.index)}
        completionHandler(session.bridge(id),nil)
    }
    private func canOpen(_ url:URL,for context:WKWebExtensionContext)->Bool {
        ["http","https"].contains(url.scheme?.lowercased() ?? "") || url.absoluteString=="about:blank" || controller.extensionContext(for:url)===context
    }
    func webExtensionController(_ controller:WKWebExtensionController,openNewWindowUsing configuration:WKWebExtension.WindowConfiguration,for context:WKWebExtensionContext,completionHandler:@escaping ((any WKWebExtensionWindow)?,(any Error)?)->Void) {
        guard let manager,!configuration.shouldBePrivate,configuration.windowType == .normal,configuration.tabURLs.allSatisfy({canOpen($0,for:context)}) else{completionHandler(nil,ExtensionValidationError.invalid("Only normal nonprivate browser windows and permitted URLs are supported."));return}
        let previous=manager.active
        let session=manager.newWindow()
        let blank=session.state.selectedTabID
        for url in configuration.tabURLs {session.newTab(url:url.absoluteString)}
        for tab in configuration.tabs {if let bridge=tab as? ExtensionTab,let source=bridge.session,!source.state.isPrivate {manager.moveTab(bridge.id,from:source,to:session)}}
        if session.state.tabs.count>1,let blank {session.close(blank,ask:false)}
        let frame=configuration.frame
        if frame.width.isFinite,frame.height.isFinite,frame.width>=640,frame.height>=400 {session.window?.setFrame(frame,display:true)}
        if !configuration.shouldBeFocused {previous?.window?.makeKeyAndOrderFront(nil)}
        session.extensionWindow?.setWindowState(configuration.windowState,for:context){_ in}
        completionHandler(session.extensionWindow,nil)
    }
    func webExtensionController(_ controller: WKWebExtensionController,openOptionsPageFor context: WKWebExtensionContext,completionHandler: @escaping ((any Error)?)->Void) {
        guard let url=context.optionsPageURL,let session=manager?.active,!session.state.isPrivate else{completionHandler(ExtensionValidationError.invalid("No options page is available."));return}
        session.newTab(url:url.absoluteString);completionHandler(nil)
    }
    func webExtensionController(_ controller: WKWebExtensionController,presentActionPopup action: WKWebExtension.Action,for context: WKWebExtensionContext,completionHandler: @escaping ((any Error)?)->Void) {
        guard let view=manager?.active?.window?.contentView,let popover=action.popupPopover else{completionHandler(ExtensionValidationError.invalid("No popup is available."));return}
        let id=contexts.first{$0.value===context}?.key
        let anchor=id.flatMap{manager?.active?.actionAnchors[$0]?.view} ?? view
        popover.behavior = .transient;popover.show(relativeTo:anchor===view ? NSRect(x:18,y:18,width:28,height:28) : anchor.bounds,of:anchor,preferredEdge:.maxX);completionHandler(nil)
    }
    func webExtensionController(_ controller: WKWebExtensionController,promptForPermissions permissions: Set<WKWebExtension.Permission>,in tab: (any WKWebExtensionTab)?,for context: WKWebExtensionContext,completionHandler: @escaping (Set<WKWebExtension.Permission>,Date?)->Void) {
        guard let session=(tab as? ExtensionTab)?.session ?? manager?.active,!session.state.isPrivate else{completionHandler([],nil);return}
        session.confirm("Allow extension permissions?",detail:"\(context.webExtension.displayName ?? "Extension")\n\(permissions.map(\.rawValue).sorted().joined(separator:"\n"))",yes:"Allow") {allowed in completionHandler(allowed ? permissions : [],nil)}
    }
    func webExtensionController(_ controller: WKWebExtensionController,promptForPermissionMatchPatterns patterns: Set<WKWebExtension.MatchPattern>,in tab: (any WKWebExtensionTab)?,for context: WKWebExtensionContext,completionHandler: @escaping (Set<WKWebExtension.MatchPattern>,Date?)->Void) {
        guard let session=(tab as? ExtensionTab)?.session ?? manager?.active,!session.state.isPrivate else{completionHandler([],nil);return}
        session.confirm("Allow extension website access?",detail:"\(context.webExtension.displayName ?? "Extension")\n\(patterns.map(\.string).sorted().joined(separator:"\n"))",yes:"Allow") {allowed in completionHandler(allowed ? patterns : [],nil)}
    }
    func webExtensionController(_ controller: WKWebExtensionController,promptForPermissionToAccess urls: Set<URL>,in tab: (any WKWebExtensionTab)?,for context: WKWebExtensionContext,completionHandler: @escaping (Set<URL>,Date?)->Void) {
        guard let session=(tab as? ExtensionTab)?.session ?? manager?.active,!session.state.isPrivate else{completionHandler([],nil);return}
        session.confirm("Allow extension website access?",detail:urls.map(\.absoluteString).sorted().joined(separator:"\n"),yes:"Allow") {allowed in completionHandler(allowed ? urls : [],nil)}
    }
}
