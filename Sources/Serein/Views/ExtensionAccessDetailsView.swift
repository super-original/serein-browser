import SwiftUI
import SereinCore

struct ExtensionAccessDetailsView:View {
    let record:InstalledExtension
    @Environment(\.dismiss) private var dismiss
    var body:some View {
        VStack(alignment:.leading,spacing:16) {
            HStack {
                Text("Requested Access").font(.title2.bold())
                Spacer()
                Button("Done"){dismiss()}.keyboardShortcut(.cancelAction)
            }
            Text(record.name).font(.headline)
            ScrollView {
                VStack(alignment:.leading,spacing:14) {
                    if let ledger=record.capabilityLedger {
                        requests("Required permissions",ledger.requiredPermissions)
                        requests("Required website access",ledger.requiredHosts)
                        requests("Optional permissions",ledger.optionalPermissions)
                        requests("Optional website access",ledger.optionalHosts)
                        Text("These are the package's original requests, not its current grants. Optional access requires separate approval. API compatibility remains incomplete.")
                            .font(.callout).foregroundStyle(.secondary)
                        if ledger.manifestWasNormalized {
                            Text("The installed manifest has a compatibility adjustment to an action label. Its permission requests are unchanged.")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                    } else {
                        Text("Original manifest details were not retained for this installation.")
                        requests("Permissions recorded at installation",record.permissions)
                        requests("Website access recorded at installation",record.hosts)
                    }
                    Text("Private browsing access is disabled.").font(.caption).foregroundStyle(.secondary)
                }.frame(maxWidth:.infinity,alignment:.leading).textSelection(.enabled)
            }
        }.padding(24).frame(width:480,height:420).accessibilityIdentifier("extension-access-details")
    }
    private func requests(_ title:String,_ values:[String])->some View {
        VStack(alignment:.leading,spacing:4) {
            Text(title).font(.subheadline.bold())
            Text(values.isEmpty ? "None" : values.joined(separator:"\n")).font(.callout)
        }
    }
}
