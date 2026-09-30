# Extension compatibility — target not achieved

**Full Chrome, Firefox and Safari extension compatibility remains the target and is not supported by this build.** The implementation uses public system WKWebExtension APIs; it does not translate arbitrary extensions into page scripts or substitute Chromium/Gecko.

## Format matrix

| Format | Current status | Exact scope |
|---|---|---|
| Chrome Manifest V2 | Partial | ZIP/unpacked loading; controlled persistent-background fixture passes limited semantics. CRX3 verification tested; CRX2/store installation absent. |
| Firefox Manifest V2 | Partial | XPI/unpacked loading; Firefox-specific semantics and APIs not implemented universally. |
| Chrome Manifest V3 | Partial | Controlled service-worker fixture passes limited semantics. Lifetime, wakeup, DNR, offscreen and full Chrome API conformance not established. |
| Firefox Manifest V3 | Untested semantics | Manifest number is accepted, which is not proof of Firefox MV3 lifecycle behavior. |
| Safari Web Extensions | Partial | Shared manifest resources can load through public WebKit; packaged `.appex`/App Store installation is not implemented. |
| Native Safari App Extensions | Blocked / unsupported | No documented third-party hosting entry point found for arbitrary SafariServices native extension handlers. |
| Legacy Safari `.safariextz` and earlier | Unsupported | No loader or compatibility runtime. |

## API and lifecycle matrix

| Family | Status | Evidence / missing work |
|---|---|---|
| Install / validate | Implemented, partial formats | Path, duplicate, size, symlink and manifest checks; omitted required API permissions reject installation/restore with an explicit list; source consent; CRX3 signature verification tested, no XPI publisher-signature validation |
| Enable / disable / remove | Partial | Fixture disable stops injection; installed records persist; disabled-extension removal now erases data by durable identity; production disable/remove and same-identity storage-reset checks pass for controlled MV2/MV3 fixtures |
| Updates | Partial | Reviewed local same-developer CRX3 updates; storage/identity/denials verified; options refresh and native cross-origin history verified. No automatic store or unsigned/XPI update protocol |
| Permissions / host access | Partial | Install prompts; fixture denied hosts do not inject; runtime permission prompts; persistent explicit grants, denials, revocations and per-site overrides |
| Private access | Unsupported by policy in this build | No extension controller in private web views; no opt-in UI |
| Tabs / windows | Partial | Native bridges, navigation, creation, focus, closure, pinning, duplication and window state; per-tab highlighted update/query/events tested; batch `tabs.highlight` absent; exhaustive ordering/concurrency unverified |
| Navigation events | Partial / untested semantics | WebKit engine events plus host tab changes; no exhaustive ordering/redirect/frame suite |
| Content scripts / isolated worlds | Partially verified | Controlled DOM injection succeeds after grant; page cannot see extension-global variable |
| Frames / dynamic scripting | Untested | No nested-frame, origin-inheritance or executeScript conformance suite |
| MV2 persistent backgrounds | Partially verified | Message → storage → tabs query → response exercised |
| MV3 service workers | Partially verified | Same controlled path; suspension, restart and queued-event semantics not established |
| Runtime messaging | Partially verified | One-shot content-to-background messaging; ports/cross-extension semantics untested |
| Storage | Partially verified | Local counter survives unload/reload with stable context ID; sync/quota/restart/error semantics untested |
| Cross-origin network | Untested | Native WebKit permission path; no complete fetch/CORS/header test suite |
| Cookies | Untested extension API | Browser normal/private cookie isolation tested separately |
| Downloads / history / bookmarks | Incomplete | Native browser features exist; not equivalent to implementing these extension API families |
| Context menus | Partial / untested | Engine and action-menu hooks exist; full native menu integration not complete |
| Request interception | Blocked or unverified per operation | Safari's documented blocking webRequest differences are material; no equivalent engine-level implementation added |
| Declarative network rules | Untested | API availability is not evidence of matching Chrome/Firefox rule limits or semantics |
| Native messaging | Unsupported | Manifest requests fail closed; no arbitrary native process access |
| External messaging / devtools | Unsupported | Manifest installation fails with a clear error |
| Commands | Partial | Public performCommand(for:) routed after native key equivalents; conflicts and real extension shortcut semantics unverified |
| Notifications | Untested | No complete consent/delivery/action semantics suite |
| Actions / popups / options | Partial | Native toolbar/popover routing and management dialogs exercised; popup DOM loads but actual desktop popup content is blank |

The current upstream [WebExtension namespace source](https://github.com/WebKit/WebKit/blob/main/Source/WebKit/WebProcess/Extensions/API/WebExtensionAPINamespace.cpp) contains compile-time/runtime feature gates for some families. Discovering a symbol there is **not** proof that the runner's system WebKit exports or enables it. No private flags are enabled.

## Controlled conformance scenarios

Fixtures are original source under `Fixtures/Extensions`, version 1.0.0, MV2 and MV3. [Run 35242885738](https://github.com/super-original/serein-browser/actions/runs/35242885738) passed both generations for: denied-host noninjection; allowed-host injection; background messaging with sender tab identity; storage write/read; browser tab query; isolated global scope; storage continuity across unload/reload; and disabling followed by navigation.

These are narrow semantic tests. They do not prove worker eviction, full frame isolation, every permission boundary, restart persistence, event ordering, all API families, or compatibility with arbitrary real extensions.

## Historical real-package audit (September 17)

Pinned sources and SHA-256 values are in [`extension-catalog.json`](../Fixtures/extension-catalog.json). The workflow downloads the original packages into an ephemeral directory and does not redistribute them. No credentials or live password vaults are used. The **scenario is package validation and context loading without permission grants**, followed by unload/data removal. None of these rows is marked functionally compatible.

| Package | Version / manifest | Observed result |
|---|---|---|
| [uBlock Origin, Chromium ZIP](https://github.com/gorhill/uBlock/releases/tag/1.75.0) | 1.75.0 / MV2 | Loads after handling the archive's enclosing directory. Blocking permission absent from WebKit's returned requested-permission set; blocking semantics not verified. |
| [uBlock Origin, Firefox XPI](https://github.com/gorhill/uBlock/releases/tag/1.75.0) | 1.75.0 / MV2 | WebKit reports invalid/empty command manifest entry; Serein rejects rather than silently claim success. |
| [Stylus, Chrome](https://github.com/openstyles/stylus/releases/tag/v2.4.13) | 2.4.13 / MV3 | Same command-validation rejection. Page styling not exercised. |
| [Violentmonkey, WebExtension](https://github.com/violentmonkey/violentmonkey/releases/tag/v2.49.0) | 2.49.0 / MV2 | Same command-validation rejection. Userscript execution not exercised. |
| [Bitwarden, Chrome](https://github.com/bitwarden/clients/releases/tag/browser-v2026.9.0) | 2026.9.0 / MV3 | Context loads without grants. Autofill, unlock, native integration and vault behavior untested. |
| [DownThemAll](https://addons.mozilla.org/firefox/addon/downthemall/) | 4.15.1 / MV2 | Context loads without grants. Its requested downloads/history/session capabilities are not all returned by WebKit. Download management not verified. |
| [Tab Session Manager](https://addons.mozilla.org/firefox/addon/tab-session-manager/) | 7.4.0 / MV3 | Context loads without grants. Tab groups, identity, download and restoration semantics not verified. |

Evidence: [run 35244059174](https://github.com/super-original/serein-browser/actions/runs/35244059174), `real-extension-results.json`. The run also contains a separate capture-harness failure; that is not an extension pass or failure. Loading packages while engine capabilities are omitted is a reason to withhold compatibility claims, not evidence that missing APIs work.

## Release blockers

A production compatibility release requires a much broader semantics suite and explicit host/engine gap resolution. Native Safari formats and engine-internal interception are major restrictions. Automatic/unsigned updates, broader signature/store trust, private opt-in, native-host isolation and API coverage are additional unimplemented work. No full custom-engine build/distribution/security-update plan has been proven feasible within the required standard free runner resources.

## Continuation: required permissions and removal

The host now compares named required manifest permissions with the system WebKit permission set at installation and restoration. If WebKit silently omits a required API permission, Serein rejects the package and lists the missing capabilities. MV2 host patterns remain website-access patterns, not API permission names. Malformed permission fields also fail closed. Recognition still does **not** establish semantic compatibility; the matrices above remain partial/unsupported.

The real-package audit now applies this same required-permission gate before loading. Earlier “loaded without permission grants” results remain historical observations of WebKit alone, not guarantees that current Serein will install those packages. Native Safari App Extensions, legacy `.safariextz`, CRX2/store installation, automatic authenticated updates and universal Chrome/Firefox semantics remain unsupported.

Removing an extension previously erased data only if a context was currently loaded. The host now queries/removes data by the durable extension UUID even after disable or restart. Controlled MV2/MV3 tests exercise production disable/remove paths and check package, record and data cleanup. This does not prove secure erasure of filesystem blocks or conformance for unrelated API families.


Current public WebKit extension-data types cover `browser.storage.local`, `browser.storage.session` and `browser.storage.sync`. Upstream [storage helper source](https://github.com/WebKit/WebKit/blob/main/Source/WebKit/UIProcess/Extensions/WebExtensionController.cpp) explicitly leaves extension-page `window.localStorage`, `window.sessionStorage` and IndexedDB deletion as unfinished work. Serein does not claim comprehensive erasure through this API. The removal confirmation discloses remaining website data; the broader Clear Website Data setting uses the website-data-store API. Targeted per-extension cleanup of those website stores remains a gap.

The same source explains a recoverable test failure: querying `.session` after unloading returns no session store and records an error. Removal now unloads the context and erases the persistent local/synchronized types by UUID, rather than querying the no-longer-loaded session type. Tests verify actual local-storage value reset on reinstall with the same identity; metadata-record disappearance is not used as a substitute.

### Current real-package admission results

[Run 36705846607](https://github.com/super-original/serein-browser/actions/runs/36705846607), commit `b36599d`, audited the same pinned versions/hashes in `Fixtures/extension-catalog.json`. **All seven real packages are currently rejected; none has passed functional compatibility scenarios.**

| Package | Current exact rejection |
|---|---|
| uBlock Origin Chromium 1.75.0 | Required `privacy`, `webRequestBlocking` omitted by system WebKit |
| uBlock Origin Firefox 1.75.0 | WebKit reports empty/invalid command manifest entry |
| Stylus Chrome 2.4.13 | WebKit reports empty/invalid command manifest entry |
| Violentmonkey 2.49.0 | WebKit reports empty/invalid command manifest entry |
| Bitwarden Chrome 2026.9.0 | Required `clipboardRead`, `idle`, `offscreen`, `sidePanel`, `webRequestAuthProvider` omitted |
| DownThemAll 4.15.1 | Required `downloads`, `downloads.open`, `history`, `sessions`, `theme` omitted |
| Tab Session Manager 7.4.0 | Required `downloads`, `identity`, `tabGroups` omitted |

These are capabilities requested by the exact packages, not a claim that every package in the same category is impossible to support. Future compatibility code must implement and test missing semantics; removing permission declarations to make installation appear successful would not meet the target.

### Host-side permissions continuation

Explicit runtime API and website permission grants, denials, and removals are now captured through public `WKWebExtensionContext` change notifications. Snapshots retain expiration dates and replace initial install grants on reload so revocation cannot silently become a grant again. Old installed records without a snapshot keep their original migration behavior. Tab-scoped `activeTab` gestures are not persisted. Per-site menu changes save immediately; private browsing remains excluded. Controlled tests exercise disk round-trip, revoked API access, restored site denial, and denied content-script injection. Run 36708785208 passed all 73 runtime checks for this follow-up; browser.storage lifecycle checks also remain passing.

### Resolving the three command-parser failures

Inspection of the hash-verified original uBlock Firefox 1.75.0, Stylus 2.4.13 and Violentmonkey 2.49.0 manifests found empty `_execute_browser_action` or `_execute_action` objects. [Chrome commands documentation](https://developer.chrome.com/docs/extensions/reference/api/commands) and [Firefox manifest documentation](https://developer.mozilla.org/en-US/docs/Mozilla/Add-ons/WebExtensions/manifest.json/commands) make descriptions optional for reserved action commands. [WebKit's parser](https://github.com/WebKit/WebKit/blob/main/Source/WebKit/UIProcess/Extensions/WebExtension.cpp) rejects empty objects before classifying reserved action names.

Serein now adds only `description: "Activate extension"` to empty, version-appropriate reserved action commands in the extracted installation copy. It preserves executable code, permissions, shortcuts and ordinary commands; original archives/directories remain unchanged. The installation dialog discloses this normalization and the lack of publisher-signature verification. Both controlled fixture generations use this preparation path. This is a parser compatibility adjustment, not a claim that any of the three real packages is functionally compatible. All three also request engine capabilities outside the observed permission set.

### Where missing capabilities can be implemented

| Gap | Feasibility / next implementation boundary |
|---|---|
| Empty reserved action-command metadata | Host-side normalization implemented; no permissions removed. Run 36709180847 verified controlled loading and re-audited the seven pinned packages. |
| Durable permissions and per-site revocation | Public context dictionaries/notifications permit host implementation; implemented and verified in both controlled manifest generations. |
| Downloads, history, sessions, tabGroups, theme | Browser models can supply much of the underlying behavior, but the inspected macOS 27 public `WKWebExtensionControllerDelegate` exposes no namespace-registration or corresponding API dispatch hook. A complete isolated extension execution/compatibility bridge or custom WebKit integration is needed; adding native browser buttons is insufficient. These are substantial implementation gaps, not proven impossible. |
| Identity, idle, clipboard access | Potential host services with explicit consent, OAuth/clipboard/privacy semantics and event handling; same missing dispatch boundary. No blanket native access granted. |
| Offscreen / sidebar / notifications | Current upstream namespace code has build/runtime gates; observed system permission omission cannot be repaired merely by implementing a delegate. A public system API path or a measured custom-WebKit plan must be established first. |
| Blocking webRequest / auth interception / privacy | Requires engine-level request ordering, credentials and settings semantics; a page script or ordinary WKNavigationDelegate cannot supply equivalent interception. No public equivalent established for arbitrary extension requests. |
| Native Safari / legacy Safari / signed Chrome packages | Native/legacy formats and CRX2 remain unsupported. CRX3 verification is tested; unrelated to manifest normalization. |

Sources: captured SDK `WKWebExtensionControllerDelegate.h` in [platform run 36705841148](https://github.com/super-original/serein-browser/actions/runs/36705841148), and [WebKit namespace implementation](https://github.com/WebKit/WebKit/blob/main/Source/WebKit/WebProcess/Extensions/API/WebExtensionAPINamespace.cpp). Upstream source is a diagnostic reference, not proof that an API is enabled in the shipped system framework. A complete custom extension execution bridge would require MV2/MV3 lifecycle, isolated worlds, permissions, messaging, and API semantics; no partial shim is being presented as full support.

[Run 36709180847](https://github.com/super-original/serein-browser/actions/runs/36709180847), `0e48afb`, passed 28 unit tests and 73 runtime checks after normalization. All three empty-command parser failures are resolved. The newly exposed exact required-permission rejections are: uBlock Firefox `dns, privacy, webRequestBlocking`; Stylus `identity, idle, offscreen, sidePanel, webRequestBlocking`; Violentmonkey `webRequestBlocking`. The other four rows are unchanged. **All seven packages still fail admission; no real-package functional compatibility is established.**

### Additional host/runtime verification

`b319b98` [run 36710297851](https://github.com/super-original/serein-browser/actions/runs/36710297851) passed 28 unit tests and all 95 runtime checks. Both controlled generations now exercise actual tabs create/get/duplicate/remove with pinned state, distinct identifiers, URL preservation, and created/removed event delivery, plus permission notification persistence and expiration filtering. These event checks establish presence for this scenario, not exhaustive ordering. The native management sheet was captured and inspected. Browser workspace moves/removals also preserve address and selected runtime state.

The next UI follow-up routes library confirmation/file dialogs to the visible library sheet, avoiding AppKit's queue behind an already-presented sheet. Remove/Install cancellation and opening an extension popup from the management sheet receive actual runtime scenarios. Popup DOM loading and native presentation are distinct from verified desktop content rendering.

### Tab highlighting workstream

The macOS 27 public `WKWebExtensionTab.setSelected` contract explicitly requires changing highlighted membership without changing the active tab; `activate` must include the active tab in the selection. Serein now keeps transient highlighted membership separate from the active page, sends public selection/deselection notifications, and supports command-click, shift-range selection and an explicit bulk-close action. Runtime fixtures exercise [tabs.highlight](https://developer.mozilla.org/en-US/docs/Mozilla/Add-ons/WebExtensions/API/tabs/highlight), highlighted/active queries and onHighlighted delivery. Verification is pending for this follow-up; exhaustive event ordering and full tab-group semantics remain separate gaps.

### Exact macOS 27 selection API gap

Run [36713799565](https://github.com/super-original/serein-browser/actions/runs/36713799565), commit `7ce1cad`, found `browser.tabs.highlight` undefined in both MV2 and MV3 backgrounds. Native command-click/range selection and bulk close passed, but the new extension call aborted its lifecycle scenario; those failures are not counted as verified compatibility. The next fixture exercises `tabs.update({highlighted:…})` independently. A working update path would not establish `tabs.highlight` support.

### Lazy tab queries and fixture isolation

The continuation found that `webView(for:)` and read-only zoom/size getters could create a web view for an unloaded tab. Those getters now report only an already loaded view (or the default zoom/empty size). Explicit activation/navigation still loads the tab; script injection into an unloaded tab is unavailable until it is loaded. New MV2/MV3 scenarios keep a background fixture tab unloaded while querying tabs. The destructive lifecycle fixture is scoped to its dedicated query URL so unrelated local pages cannot run concurrent tab/storage probes. Prior multiselection/count failures are retained as failed evidence; the corrected scenarios require a fresh run.

The lifecycle fixture serializes its destructive probe body: permission grants and reloads can produce overlapping content-script messages, which otherwise compete over the same selected tabs. This controls the test workload; it is not evidence of cross-extension event ordering or concurrent selection conformance.

The separate native-message experiment passed all eight checks in [36719132526](https://github.com/super-original/serein-browser/actions/runs/36719132526), `f20b79b`: nativeMessaging recognized, pre-grant rejection before host execution, context-bound constant reply after explicit grant, and unknown-application rejection, for MV2 and MV3. It registers a real WebKit tab/window bridge, uses copied fixtures and a unique controller configuration. This proves a limited public transport path. Production native messaging remains rejected; no process launch, filesystem or browser-data adapter has been enabled.

`8245e2a` [run 36719782728](https://github.com/super-original/serein-browser/actions/runs/36719782728) passes all 140 browser checks and all eight separate native-message transport checks. Both generations now pass exact two-tab highlighted queries, activation and highlighted-event checks with an explicitly serialized workload, preserve an unloaded tab during querying, and reset local storage to counter 1 after same-identity reinstall. `browser.tabs.highlight` is still absent. All seven real-package admission failures remain; these controlled results do not establish universal compatibility.

### CRX3 archive verification

CRX3 installation verifies every RSA PKCS#1/SHA-256 or P-256/SHA-256 proof and requires a verified key matching the declared extension ID. Original archive hash and developer-key identity persist with the installed record. This establishes self-signed archive integrity, **not Chrome Web Store approval**. New signed installs preserve the verified developer ID as `browser.runtime.id` through public `WKWebExtensionContext.uniqueIdentifier`; existing records retain their stored identity. Runtime verification passes in `f7ef361` run 36724793938. Other Chrome identity/URL-dependent behavior, automatic signed updates, CRX2, publisher-pinned store trust and verified-contents per-file enforcement remain unsupported. Normalized installed metadata is explicitly distinguished from the signed original. Required unsupported APIs still reject installation.

The implementation follows Chromium's [wire format](https://chromium.googlesource.com/chromium/src/+/main/components/crx_file/crx3.proto) and [actual verifier](https://chromium.googlesource.com/chromium/src/+/main/components/crx_file/crx_verifier.cc); the latter uses RSA_PKCS1_SHA256 despite the proto's older PSS comment. Limits: 65 MiB package, 1 MiB header, 32 proofs, 8 KiB encoded keys/signatures and maximum 8192-bit RSA keys. Unknown protobuf fields are skipped; duplicate required scalar fields and unsupported wire encodings fail closed. ZIP64 and compression methods other than stored/deflate remain unsupported.

ZIP/XPI/CRX extraction uses a private snapshot of validated bytes. Streaming zlib validation checks actual expanded size, exact compressed consumption and CRC before extraction; central/local metadata and nonregular Unix entry kinds are checked. Self-signed content is still untrusted. Independent Python-cryptography signatures exercise both algorithms, tampering, mismatched developer IDs and invalid extra proofs. Run [36723768551](https://github.com/super-original/serein-browser/actions/runs/36723768551), `b854f84`, passed 39 unit tests, all 144 browser checks and all 12 separate bridge checks. Signed fixture consent, load and persisted signature identity pass. The native consent screenshot was retrieved and inspected: provenance, original/developer-ID qualification and Cancel/Install controls are readable. The initial `26fc533` run passed signature tests but correctly rejected a fixture lacking the WebKit-required description; that manifest was corrected and re-signed. The actual desktop content gate remains failed.


The archive extractor now writes only checked UTF-8 central/local names and file payloads into an exclusively created private directory, using public Darwin file creation and streaming zlib. It ignores alternate-name extras and filesystem metadata rather than passing them to a different parser; legacy-encoded archives relying on those extras remain unsupported. The [PKWARE ZIP specification, section 4.6.9](https://pkware.cachefly.net/webdocs/casestudies/APPNOTE.TXT) defines an alternate Unicode path field, motivating an explicit single-parser boundary. Tests cover alternate-path metadata and preservation of existing destinations. This follow-up is pending CI.


### Manual signed updates (partial verification)

The manager now offers a local CRX3 update for an existing signed extension. Proofs must bind to the same developer key and ID, and the numeric [Chrome manifest version](https://developer.chrome.com/docs/extensions/reference/manifest/version) must increase. Required unsupported APIs still reject the candidate before consent. The native review lists new and total requested permissions/sites. Existing denials and revoked old grants remain; new required permissions are granted only after this review. Disabled extensions stay disabled. Unsigned/XPI updates and automatic store update protocols remain unsupported.

A candidate moves to its own immutable version directory before the extension registry is atomically replaced. The old directory remains until activation/cleanup succeeds. A process interruption can leave an unused directory, but the registry points to one complete package; full power-loss durability and process-kill fault injection are not established. If post-commit activation fails, the new version is disabled and previous package files are retained. This does not roll back extension-authored storage migrations.

The record UUID, runtime ID and WebKit resource origin are preserved. Existing loaded extension pages reload after a successful update; unloaded pages stay unloaded. Origins are now persisted for future reloads; legacy records without a saved origin capture their current origin when next loaded, and older unidentifiable extension-page URLs may need reopening. Tests cover version/key rejection, failed registry writes, immutable package replacement, chooser/consent cancellation, added permissions, storage and open options pages, disabled updates, and retained revocation/site denial. Run 36731114526 at `835870b` passed signed-update checks except the open options document: its empty body revealed that ordinary WKWebView configurations cannot host extension pages. Public context-configuration/view replacement fixed this: run 36733548661 at `237cd3d` passed all 178 browser checks, including initial options content, updated content and native Back/Forward across origins. Follow-up `1748c81`, run 36734574259, passes all 183 browser checks including re-enable/restoration, page-initiated navigation and JavaScript Back/forward-list preservation. Desktop content remains blank; DOM results are not visual proof.

Resource navigation follow-up: host origin handoffs now preflight MV2/MV3 web-accessible resource rules. Public-resource allowance and private/unmatched-origin denial have runtime scenarios; results pending. Dynamic URL rules are denied for this handoff, and redirects/POST semantics remain unverified. Re-enable/options restoration passed run 36734574259 but failed two checks in run 36735423590; reliability is under investigation, not established.
