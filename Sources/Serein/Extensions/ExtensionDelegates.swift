import AppKit
import WebKit
import SereinCore

extension ExtensionHost: WKWebExtensionControllerDelegate {
    func webExtensionController(_ controller: WKWebExtensionController,openWindowsFor context: WKWebExtensionContext) -> [any WKWebExtensionWindow] {
        manager?.windows.filter{!$0.session.state.isPrivate}.compactMap{$0.session.extensionWindow} ?? []
    }
    func webExtensionController(_ controller: WKWebExtensionController,focusedWindowFor context: WKWebExtensionContext) -> (any WKWebExtensionWindow)? {
        guard let session=manager?.active,!session.state.isPrivate else{return nil};return session.extensionWindow
    }
    func webExtensionController(_ controller: WKWebExtensionController,openNewTabUsing configuration: WKWebExtension.TabConfiguration,for context: WKWebExtensionContext,completionHandler: @escaping ((any WKWebExtensionTab)?,(any Error)?)->Void) {
        guard let session=(configuration.window as? ExtensionWindow)?.session ?? manager?.active,!session.state.isPrivate else{completionHandler(nil,ExtensionValidationError.invalid("No normal browsing window is available."));return}
        let id=session.newTab(url:configuration.url?.absoluteString ?? "about:blank",select:configuration.shouldBeActive)
        if configuration.shouldBePinned {session.setKind(id,.pinned)}
        completionHandler(session.bridge(id),nil)
    }
    func webExtensionController(_ controller: WKWebExtensionController,openOptionsPageFor context: WKWebExtensionContext,completionHandler: @escaping ((any Error)?)->Void) {
        guard let url=context.optionsPageURL,let session=manager?.active,!session.state.isPrivate else{completionHandler(ExtensionValidationError.invalid("No options page is available."));return}
        session.newTab(url:url.absoluteString);completionHandler(nil)
    }
    func webExtensionController(_ controller: WKWebExtensionController,presentActionPopup action: WKWebExtension.Action,for context: WKWebExtensionContext,completionHandler: @escaping ((any Error)?)->Void) {
        guard let view=manager?.active?.window?.contentView,let popover=action.popupPopover else{completionHandler(ExtensionValidationError.invalid("No popup is available."));return}
        popover.behavior = .transient;popover.show(relativeTo:NSRect(x:18,y:18,width:28,height:28),of:view,preferredEdge:.maxX);completionHandler(nil)
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
