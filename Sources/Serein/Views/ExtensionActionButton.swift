import SwiftUI
import WebKit

@MainActor final class WeakActionAnchor {weak var view:NSView?;init(_ view:NSView){self.view=view}}

struct ExtensionActionButton:NSViewRepresentable {
    let record:InstalledExtension
    let session:BrowserSession
    let revision:Int
    func makeCoordinator()->Coordinator {Coordinator(id:record.id,session:session)}
    func makeNSView(context:Context)->NSButton {
        let button=NSButton(image:NSImage(systemSymbolName:"puzzlepiece.extension",accessibilityDescription:record.name)!,target:context.coordinator,action:#selector(Coordinator.performExtensionAction))
        button.bezelStyle = .glass;button.imagePosition = .imageOnly
        session.actionAnchors[record.id]=WeakActionAnchor(button)
        return button
    }
    func updateNSView(_ button:NSButton,context:Context) {
        guard let host=session.extensions,let extensionContext=host.contexts[record.id] else{button.isEnabled=false;return}
        let action=extensionContext.action(for:session.state.selectedTabID.map{session.bridge($0)})
        button.toolTip=action?.label ?? record.name
        button.setAccessibilityLabel(action?.label ?? record.name)
        button.isEnabled=action?.isEnabled ?? false
        if let icon=action?.icon(for:NSSize(width:18,height:18)){button.image=icon}
    }
    @MainActor final class Coordinator:NSObject {
        let id:UUID;weak var session:BrowserSession?
        init(id:UUID,session:BrowserSession){self.id=id;self.session=session}
        @objc func performExtensionAction(){guard let session else{return};session.extensions?.perform(id,in:session)}
    }
}
