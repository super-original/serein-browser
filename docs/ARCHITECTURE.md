# Architecture

## Components

| Component | Responsibility |
|---|---|
| `SereinCore` | Codable window/workspace/tab state, restoration repair, address resolution, origin comparison, extension-package validation. No UI dependency. |
| `BrowserManager`, `BrowserSession` | Window ownership, debounced atomic session writes, current navigation and UI state, stable extension identities. |
| `BrowserWindowController`, SwiftUI views | Native NSWindow traffic lights, responder chain and menus; SwiftUI sidebar, tabs, settings and address controls. |
| `TabRuntime` | One lazily created WKWebView per visited tab, navigation policy, KVO observations, failure and process-termination state. |
| `LibraryStore`, `DownloadStore` | Saved bookmarks/history; WKDownload delegation and user-selected destination panels. |
| `ExtensionHost`, delegates and bridges | Public WKWebExtensionController, package validation, permission consent, context lifecycle, browser events, tab/window operations and actions. |
| `RuntimeVerification`, fixtures | Deterministic scenarios executed inside the actual application on a macOS 27 graphical runner. |

AppKit owns window lifecycle and native menu/responder behavior. SwiftUI expresses the custom vertical-tab geometry. The interop boundary embeds WKWebView solely for website/extension content. There is no HTML browser chrome or JavaScript-to-native extension polyfill with unrestricted access.

WKWebView is retained instead of rewriting around the newer SwiftUI WebPage/WebView: the public extension-controller attachment and existing-tab browser delegate model require explicit WKWebView identity and configuration. This is a specific interoperability requirement, not an assumption that older APIs render more natively. New macOS 27 text-field styling is used; native Liquid Glass renders browser surfaces.

## Persistence and privacy

Normal windows share the default persistent WebKit website store. Each private window receives its own `WKWebsiteDataStore.nonPersistent()` store. Private windows are filtered from serialization even if inserted after SavedSession initialization. Private history is never added to LibraryStore. Extensions are not attached to private web views, and extension window enumerations omit private windows.

Tabs and workspaces restore from a versioned JSON session. Corrupt session input is preserved as a recovery file. Unknown future schema versions fail rather than silently overwrite. Bookmarks and history are separate atomic JSON files. Ordinary window frames restore with display-bound clamping; opt-in cross-launch HTTP(S) Back/Forward state is saved atomically in the same JSON. SavedNavigationHistory validates identity, current URL, SHA-256 integrity and bounded payloads; runtime restoration additionally requires the exact OS/WebKit build. Private, loading, failed and currently edited tabs are excluded. Opaque state can contain page/form/frame data and is owner-only but not encrypted. Invalid optional state preserves URL-only restoration. Unloaded ordinary tabs retain validated state; file and extension histories remain URL-only across launches. Live transfer and manual suspension preserve public in-memory history/zoom state. History is bounded to 3,000 URLs; repeated visits update the recent entry. This is not a full visit-level history database.

Manual tab unloading requires explicit confirmation and excludes visible split panes. No automatic tab suspension is enabled: reliably detecting every site's unsaved state or active media has not been established. A content script in a separate WebKit execution world detects form input and protects close/quit/navigation flows. This does not cover every kind of unsaved application state.

## Extension trust boundary

Extensions execute in WebKit's extension contexts. Browser-native code is reached only through documented delegates. Native messaging requires a verified CRX3 identity and explicit user registration of a compatible native host; unsigned/XPI native identities are rejected. No extension receives arbitrary filesystem, process-launch, shell, or Swift evaluation access. Website schemes are restricted; external application links require confirmation.

ZIP/XPI installation validates central and local paths, size limits, compression types, duplicate names and Unix symlinks before extraction. CRX3 signatures verify the original archive/developer identity before command normalization; this does not attest Chrome Web Store approval. Safari Web Extension bundles load through the public bundle initializer, but native Safari App Extensions and legacy formats remain unsupported. A source-trust warning is shown before installing an unsigned package. Permission grants are not evidence of publisher identity.

The browser application is not yet App Sandbox constrained. WebKit process isolation is supplied by the system; that does not establish a complete browser threat model. Security review, package-parser fuzzing, external messaging policy, native-host isolation, update authenticity, credential storage, and private-browsing extension opt-in remain release gates.

## Reliability and resources

All browser/UI mutations are main-actor isolated. WebKit performs rendering in its system subprocesses. Views are created lazily; restoring a tab does not deliberately launch its renderer until selected (extension inspection may request a view). Package extraction and some persistence still use synchronous filesystem operations and must be moved off the main actor before a performance-sensitive production release.

All build dependencies are system frameworks. Actions are pinned to immutable commits. The GitHub runner label selects a moving hosted image, so a reproducible source recipe does not imply bit-for-bit identical results on future images. Every run records OS, Xcode, Swift, SDK, architecture and minimum target. See research for observed image drift.

## Registered native applications

`NativeMessagingManager` is the production WKWebExtension native delegate adapter. Registrations bind a browser record, verified CRX3 extension ID and developer-key fingerprint to a validated Chrome host manifest. Explicit UI consent precedes persistence. Every open, outgoing port message and incoming delivery rechecks the live context and nativeMessaging permission. Unknown host names never become filesystem paths.

`NativeMessageTransport` owns one direct `Process` launch, framed pipes and its own child lifetime on a worker thread. Bounded queues isolate WebKit's main-actor callbacks from blocking IO. A wake pipe makes idle connections event-driven. Cancellation closes the owned process; awaitable close returns after reaping. The quit delegate waits for native cleanup before confirming termination and rechecks the open-document snapshot before saving. Runtime tests separately cover options pages, background execution worlds, permission/registration revocation and supervised process exit; their passing status is tracked in VERIFICATION.md rather than inferred here.

## Runtime verification isolation

The main app writes its own PID and partial progress checkpoints to an isolated evidence root. The supervisor records executable, fixture arguments and process start time before input or shutdown, then stops only that matching process before independent crash/fullscreen/quit/download runs. A timeout remains a failure, and partial results never satisfy the aggregate gate. Public extension background loading has a bounded diagnostic completion; missing completion and context errors remain explicit failed assertions. These measures prevent one failed scenario from being mistaken for failures in later independent app processes.
