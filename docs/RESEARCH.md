# macOS 27 research and feasibility

Research date: 2026-09-17. Availability is checked against Apple's current documentation, WWDC26 material, compiler diagnostics and public SDK headers/Swift interfaces exported by the platform workflow. The SDK files are evidence artifacts, not copied implementation code.

## Platform actually observed

- Standard GitHub `xcode-27` runner, arm64, macOS 27.0 **26A5406e**. Native NSWindow launch and desktop capture succeeded in [platform run 35239435980](https://github.com/super-original/serein-browser/actions/runs/35239435980).
- Observed images supplied both Xcode 27 beta 6 **27A5252f**, Swift 6.4 `swiftlang-6.4.0.33.1`, and release candidate **27A266a**, `swiftlang-6.4.0.34.1`, under `/Applications/Xcode_27.0.app`. SDK 27.0 in both. The latter's alias resolves to `/Applications/Xcode_27_Release_Candidate.app`.
- The runtime is a prerelease build; this is **not** a verification claim for the final shipping macOS 27 release. Preview-image drift is a reproducibility limitation. CI records the actual inventory instead of treating the alias as an immutable toolchain.
- Runner-reported RAM: 7,516,192,768 bytes. One observed clean image had 36 GiB free on its 135 GiB volume. GitHub documents the standard arm64 runner as 3 CPUs, 7 GB RAM and 14 GB SSD; observed free capacity must not be treated as an allocation guarantee.

Sources: [GitHub runner specifications](https://docs.github.com/en/actions/reference/runners/github-hosted-runners), [xcode-27 image manifest](https://github.com/actions/runner-images/blob/main/images/macos/xcode-27-arm64-Readme.md), [Actions billing](https://docs.github.com/en/billing/concepts/product-billing/github-actions), [usage limits](https://docs.github.com/en/actions/reference/limits).

Standard hosted Actions usage is free for public repositories. No larger runner, paid storage purchase, self-hosted Mac, remote paid Mac, or local SDK is configured. Workflows use short timeouts and cancel superseded jobs. Artifacts have bounded retention. The app is tiny compared with an engine build and uses the system WebKit security-update path.

## 26 → 27 API and behavior decisions

| Area | Verified evidence and availability | Decision / remaining validation |
|---|---|---|
| Liquid Glass | NSGlassEffectView and SwiftUI glass surfaces arrived in 26. SDK27 adds `NSGlassEffectView.effectIsInteractive` at 27.0. WWDC26 describes updated sidebar/control treatment and interaction feedback. | Use actual system glass; no generic blur/gradient imitation. A single sidebar surface avoids nested glass composition. Interactive control feedback and contrast need screenshot/AX coverage. |
| Text controls | SDK27 Swift interface marks `.bordered` text-field style available at 27.0; rounded/square styles are soft-deprecated (sentinel version 100000). | Use `.textFieldStyle(.bordered)` for address, find and settings fields. Do not interpret soft deprecation as removal. |
| Window chrome | SDK27 retains public full-size content/titlebar APIs. Titlebar accessories may draw beyond their bounds when linked on 27. | AppKit owns genuine traffic lights, focus and fullscreen. Geometry is adapted to system rendering. No private window buttons or undocumented titlebar selectors. |
| Scroll edges | Release notes fix unwanted edge effects with no visible scrollers; WWDC26 describes hard edges below free-floating title text. | Keep web page scroll behavior in WebKit. Inspect edges with real scrolling; no hand-drawn imitation of native edge effects. |
| Sidebars/tabs | 27 introduces semantic `.tabs` Picker styling and AppKit segmented/toolbar group tab roles. | Zen's vertical tabs and workspace dots require a custom native layout, with native buttons and labels. A segmented picker is not a substitute for Zen's layout. Full VoiceOver tab semantics remain a gap. |
| Menus | 27 changes default image visibility; 27-linked apps can hide both symbol and nonsymbol item images. Public preferred-image APIs handle intentional exceptions. | Text-first native menus follow the system default, with no blanket forced SF-symbol decoration. |
| Focus/interoperability | WWDC26 recommends gesture recognizers and automatic key-view-loop recalculation. NSView/NSControl gain observation integration. | Enable `autorecalculatesKeyViewLoop`; use native menu selectors and narrow NSViewRepresentable boundaries. No mouse-tracking loops. Test Cmd-L, editing, tab cycling and split-pane focus. |
| Accessibility | System glass responds to accessibility preferences; SwiftUI exposes Reduce Motion and Reduce Transparency environments. | Respect Reduce Motion in custom transitions. Reduce Transparency, increased contrast and VoiceOver must be inspected on the runner rather than inferred from compilation. |

Sources: [macOS 27 release notes](https://developer.apple.com/documentation/macos-release-notes/macos-27-release-notes), [Xcode 27 notes](https://developer.apple.com/documentation/xcode-release-notes/xcode-27-release-notes), [SwiftUI updates](https://developer.apple.com/documentation/updates/swiftui), [AppKit updates](https://developer.apple.com/documentation/updates/appkit), [Modernize your AppKit app, WWDC26 289](https://developer.apple.com/videos/play/wwdc2026/289/), [SwiftUI/AppKit interoperability, 272](https://developer.apple.com/videos/play/wwdc2026/272/), [What's new in SwiftUI, 269](https://developer.apple.com/videos/play/wwdc2026/269/), [Applying Liquid Glass](https://developer.apple.com/documentation/swiftui/applying-liquid-glass-to-custom-views), [Landmarks sample](https://developer.apple.com/documentation/swiftui/landmarks-building-an-app-with-liquid-glass).

The Landmarks sample explains material composition and content hierarchy, not Zen geometry. Its API examples were compared with SDK availability; sample usage alone was not accepted as availability evidence. The project does not redistribute Apple's sample or SDK source.

## WebKit

`WKWebExtension`, controller, context, tab/window protocols and extension data records are public from macOS 15.4. Their availability does not imply Chrome/Firefox semantic parity. The controller must be attached to each WKWebView configuration, and the app must deliver browser events and implement native tab/window operations. Private windows deliberately have no controller.

SDK27 compiler inspection found main-actor/sendable completion-handler requirements on navigation, UI and download delegates. The source was corrected instead of suppressing the optional-protocol near-match warnings. The extension data-record async method is named `dataRecords(ofTypes:)`, and changed URL properties use `.URL`; these were verified rather than inferred.

System WKNavigationDelegate handles redirects, policy, failure and content-process termination. WKDownload delegates choose paths through native save panels. Camera/microphone requests receive per-page consent. No undocumented process termination, process pooling, engine setting or WebKit preference is used. Process-crash recovery has a visible reload state, but real crash injection remains a required test. Media, geolocation, full-screen video, file-upload and download-resume coverage are incomplete.

Sources: [WKWebExtension](https://developer.apple.com/documentation/webkit/wkwebextension), [controller](https://developer.apple.com/documentation/webkit/wkwebextensioncontroller), [controller delegate](https://developer.apple.com/documentation/webkit/wkwebextensioncontrollerdelegate), [WKUIDelegate](https://developer.apple.com/documentation/webkit/wkuidelegate), [WKDownload](https://developer.apple.com/documentation/webkit/wkdownload), [Safari 27 / WebKit WWDC26](https://developer.apple.com/videos/play/wwdc2026/204/).

## Extension-format restrictions and alternatives

Chrome MV2 persistent backgrounds and MV3 service workers are distinct execution models. Firefox has its own manifest/lifecycle and API semantics. Safari Web Extensions share a web manifest model, while Safari App Extensions implement SafariServices native handlers. Legacy `.safariextz` is another format. No documented API was found for hosting arbitrary native Safari App Extensions inside an unrelated WKWebView browser.

Apple's compatibility guide explicitly lists differences such as blocking webRequest behavior and unsupported update URLs. It is a Safari guide with historical version notes, not an exhaustive macOS 27 WKWebExtension contract. Mozilla documents divergent content worlds, proxy APIs, lifecycle and tab-close semantics. These differences prevent a claim of full compatibility from a manifest-loader demo.

Safari 27 adds an App Store Connect packaging route for Web Extensions without an Xcode app project. That distribution change does not make native Safari extension handlers portable and does not certify Serein's compatibility.

Sources: [Apple compatibility guide](https://developer.apple.com/documentation/safariservices/assessing-your-safari-web-extension-s-browser-compatibility), [Safari App Extensions](https://developer.apple.com/documentation/safariservices/safari-app-extensions), [Safari packaging](https://developer.apple.com/documentation/safariservices/packaging-and-distributing-safari-web-extensions-with-app-store-connect), [Chrome MV3](https://developer.chrome.com/docs/extensions/develop/migrate/what-is-mv3), [Mozilla incompatibilities](https://developer.mozilla.org/en-US/docs/Mozilla/Add-ons/WebExtensions/Chrome_incompatibilities).

Missing browser operations can be added to delegates. Missing host-facing API families need public engine support or a carefully isolated compatibility implementation. Exact engine-internal request interception/content-world semantics cannot be promised through injected page scripts. A custom WebKit build is therefore a research alternative, **not an implemented solution**. No engine build is started without a feasible resource/security-maintenance plan. WebKit's build procedure produces the engine and tools, but does not establish that a clean build fits this 7 GB / standard-disk / six-hour runner class. Source/build disk, peak memory and duration have not been measured for a full engine build, so feasibility remains unestablished. Upstream binary archives are not proof of a redistributable, macOS 27-compatible secure browser runtime. See [WebKit build instructions](https://webkit.org/building-webkit/) and [source/archive entry points](https://webkit.org/getting-the-code/).

No Chromium/Gecko substitution, paid runner, lower deployment target or macOS 26 visual evidence is used to close these gaps.
