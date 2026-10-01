# Extension compatibility — target not achieved

**Full Chrome, Firefox and Safari extension compatibility remains the target and is not supported by this build.** The implementation uses public system WKWebExtension APIs; it does not translate arbitrary extensions into page scripts or substitute Chromium/Gecko.

## Format matrix

| Format | Current status | Exact scope |
|---|---|---|
| Chrome Manifest V2 | Partial | ZIP/unpacked loading; controlled persistent-background fixture passes limited semantics. CRX3 verification tested; CRX2/store installation absent. |
| Firefox Manifest V2 | Partial | XPI/unpacked loading; Firefox-specific semantics and APIs not implemented universally. |
| Chrome Manifest V3 | Partial | Controlled service-worker fixture passes limited semantics. Lifetime, wakeup, DNR, offscreen and full Chrome API conformance not established. |
| Firefox Manifest V3 | Partial / functional failures | uBO Lite 2026.930.1227 loads, but shipped-rule blocking and original options/background messaging fail; no functional compatibility established. |
| Safari Web Extensions | Partial | Shared manifest resources load through public WebKit; intact Safari Web Extension `.appex` installation passes controlled runtime checks. App Store acquisition and Safari native handlers remain unsupported. |
| Native Safari App Extensions | Blocked / unsupported | No documented third-party hosting entry point found for arbitrary SafariServices native extension handlers. |
| Legacy Safari `.safariextz` and earlier | Unsupported | No loader or compatibility runtime. |

## API and lifecycle matrix

| Family | Status | Evidence / missing work |
|---|---|---|
| Install / validate | Implemented, partial formats | Path, duplicate, size, symlink and manifest checks; omitted required API permissions reject installation/restore with an explicit list; source consent; CRX3 signature verification tested, no XPI publisher-signature validation |
| Enable / disable / remove | Partial | Fixture disable stops injection; installed records persist; disabled-extension removal now erases data by durable identity; production disable/remove and same-identity storage-reset checks pass for controlled MV2/MV3 fixtures |
| Updates | Partial | Reviewed local same-developer CRX3 updates; storage/identity/denials verified; options refresh and native cross-origin navigation exercised, repeated context recovery/back-list counts pass at `d4c80d1`; complete back/forward URL-list and zoom comparisons pass at `e32960d`. No automatic store or unsigned/XPI update protocol |
| Permissions / host access | Partial, network enforcement failures | All 12 stale-context/private/tab native-consent checks pass at `a16b46c`; saved grants/denials and content injection are exercised. Revoked background fetch access still succeeds after two seconds in both generations. |
| Private access | Unsupported by policy in this build | No extension controller in private web views; no opt-in UI |
| Tabs / windows | Partial | Native bridges, navigation, creation, focus, closure, pinning, duplication and window state; per-tab highlighted update/query/events tested; batch `tabs.highlight` absent; exhaustive ordering/concurrency unverified |
| Tab zoom | Partial / unsupported event | Native setter and public notification hook implemented; `tabs.onZoomChange` is absent in both tested backgrounds. Set/get/reset verified at `f3757e9`; modes/scopes and per-site persistence unimplemented |
| Navigation events | Partial / untested semantics | WebKit engine events plus host tab changes; no exhaustive ordering/redirect/frame suite |
| Content scripts / isolated worlds | Partially verified | Controlled DOM injection succeeds after grant; page cannot see extension-global variable |
| Frames / dynamic scripting | Partially verified | `53d93bc` passes same-origin injection, unrequested-origin exclusion and isolated globals in HTTP iframes for both generations; nested-frame origin inheritance and executeScript conformance remain untested |
| MV2 persistent backgrounds | Partially verified | Message → storage → tabs query → response exercised |
| MV3 service workers | Partially verified | Same controlled path; suspension, restart and queued-event semantics not established |
| Runtime messaging | Partially verified | One-shot messaging and single-recipient runtime ports: ordered nested payloads, sender metadata and explicit disconnect pass in MV2/MV3 at `029feec`; document-bound retest at `32b17e3` fails disable-disconnect for both MV2/MV3 (earlier readiness could consume the previous page). Cross-extension and multi-recipient semantics remain untested |
| Storage | Partially verified | Local counter survives unload/reload with stable context ID; sync/quota/restart/error semantics untested |
| Cross-origin network | Partial, failing revocation / redirect cases | Initial denied and granted requests pass. Both generations retain fetch access after host revocation; MV2 reads a denied redirect host. Public context recreation is under investigation; no complete header/auth/cross-origin suite. |
| Cookies | Partial, event/error mismatches | Set/get/remove and ordinary-store/private exclusion pass in MV2/MV3. Host denial hides the value but returns null instead of rejection. Required onChanged payload/order is not verified; observed event arrays are empty. |
| Downloads / history / bookmarks | Incomplete | Native browser features exist; not equivalent to implementing these extension API families |
| Context menus | Partial / untested | Engine and action-menu hooks exist; full native menu integration not complete |
| Request interception | Blocked or unverified per operation | Safari's documented blocking webRequest differences are material; no equivalent engine-level implementation added |
| Declarative network rules | Failing real-package scenario | uBO Lite loads but its shipped EasyList rule does not block the matching loopback script at `a16b46c`. Engine rule activation/background startup are being isolated; Chrome/Firefox rule limits and full semantics remain unverified. |
| Native messaging | Partial, controlled runtime verified | Verified CRX3 identity, explicit Chrome host-manifest registration and consent, framed stdio; Firefox host identities and automatic discovery unsupported |
| External messaging / devtools | Unsupported | Manifest installation fails with a clear error |
| Commands | Partial | Actual MV2/MV3 keyboard delivery, management-menu dispatch and private exclusion pass at `e32960d`; conflicts, remapping, global and real-extension shortcuts remain unverified |
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

[Run 36746894298](https://github.com/super-original/serein-browser/actions/runs/36746894298), commit `17c03c2`, re-audited the pinned versions/hashes in `Fixtures/extension-catalog.json` after reserved-command normalization. **All seven real packages are currently rejected; none has passed functional compatibility scenarios.**

| Package | Current exact rejection |
|---|---|
| uBlock Origin Chromium 1.75.0 | Required `privacy`, `webRequestBlocking` omitted by system WebKit |
| uBlock Origin Firefox 1.75.0 | Required `dns`, `privacy`, `webRequestBlocking` omitted |
| Stylus Chrome 2.4.13 | Required `identity`, `idle`, `offscreen`, `sidePanel`, `webRequestBlocking` omitted |
| Violentmonkey 2.49.0 | Required `webRequestBlocking` omitted |
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

Resource navigation follow-up: host origin handoffs now preflight MV2/MV3 web-accessible resource rules. Public-resource allowance and private/unmatched-origin denial pass on macOS 27 in run 36736623545. Dynamic URL rules are denied for this handoff, and redirects/POST semantics remain unverified. Re-enable/options restoration passed run 36734574259 but failed two checks in run 36735423590; reliability is under investigation, not established.

### Zoom semantics continuation (verification pending)

Native zoom controls and the public extension tab delegate now use the same setter and report `.zoomFactor` changes to WebKit. Zero restores Serein’s default factor of 1; invalid/nonfinite factors and missing tabs return an error instead of reporting success. Controlled MV2/MV3 checks exercise 1.25 set/get, zero reset, and old/new values in `tabs.onZoomChange`. These changes await exact-head runtime evidence. Per-origin zoom persistence, zoom settings modes/scopes, and complete cross-browser range differences are not implemented or claimed. See [Firefox setZoom contract](https://developer.mozilla.org/en-US/docs/Mozilla/Add-ons/WebExtensions/API/tabs/setZoom) and [Chrome zoom event contract](https://developer.chrome.com/docs/extensions/reference/api/tabs#event-onZoomChange).

Run [36746894298](https://github.com/super-original/serein-browser/actions/runs/36746894298) at `17c03c2` establishes that `tabs.onZoomChange` is **undefined** in both system-WebKit background environments, despite the public native `.zoomFactor` notification hook. That unsupported event is now isolated from other lifecycle tests, with a failing compatibility assertion retained. Set/get/reset were not reached in that run and are not yet verified.

The inspected [upstream tabs interface](https://github.com/WebKit/WebKit/blob/main/Source/WebKit/WebProcess/Extensions/Interfaces/WebExtensionAPITabs.idl) exposes `getZoom`/`setZoom` but has no `onZoomChange` event member. This corroborates the observed gap, without treating upstream main as the shipped system implementation. A native property notification alone cannot install a missing JavaScript namespace member; no public namespace-registration hook has been established.

### Subframe boundary fixtures (verification pending)

Both controlled generations declare a separate `all_frames` script for the permitted loopback host. A deterministic parent loads same-origin `127.0.0.1` and unrequested `localhost` children. Reports are accepted only from the expected frame window and origin; checks require permitted-frame injection, no unrequested-frame marker, and no extension-global visibility in page JavaScript. No third-party extension packages or credentials are involved. These are HTTP iframe/isolated-world checks, not comprehensive sandbox, nested-frame, `about:blank`, `srcdoc`, or dynamic-injection conformance. [Content-script frame and world semantics](https://developer.chrome.com/docs/extensions/develop/concepts/content-scripts#specify-frames).

At `f3757e9`, [run 36747921197](https://github.com/super-original/serein-browser/actions/runs/36747921197), both MV2/MV3 zoom set/get (1.25) and zero reset to 1 pass. Both zoom-event assertions fail as expected for the missing interface; unrelated lifecycle scenarios run again and pass. No event polyfill or full zoom-settings compatibility is claimed.

### Recovery, window completion and commands follow-up

At `d4c80d1`, all three options re-enable cycles load the updated document and retain back-list count. The host first loads the recreated context's resource, then replaces that transient list with saved opaque interaction state. Full back/forward URL-list and zoom checks are pending. At `3556d1`, all eight MV2/MV3 window-close delegate tests pass: completion waits for consent, cancellation/stale tabs report errors, and success follows actual removal. These are delegate tests, not JavaScript promise tests. A Commands menu and actual keyboard-event/private-window checks are now being added; global shortcuts, remapping and conflicts remain unverified.


### Window API URL visibility investigation

At `5022078`, MV2 and MV3 `windows.create`/`get({populate:true})` return the expected single tab, but its `url` is an empty string instead of the requested `about:blank`. Bounds, resize, focus, removal and create/remove events pass. The failing URL assertions remain in the suite. Granted-HTTP coverage and an explicit native `tabs` grant assertion are being added to distinguish metadata filtering from window/tab adapter failures. No permission-bypass delegate is enabled to conceal this difference.

The observed redaction is consistent with upstream [URL permission filtering](https://github.com/WebKit/WebKit/blob/b55be06b347f8530b33e876cc40157df6fd5ccf8/Source/WebKit/UIProcess/Extensions/WebExtensionContext.cpp), which checks supported URL schemes before host-pattern grants. This is an inference from upstream source, not proof of the exact binary's implementation. Public context permission status and actual returned JavaScript payloads are the runtime evidence.

At `29dabbf`, granted-HTTP populated-window URLs pass in both generations; `about:blank` remains empty. Recreated extension options pages now preserve history/zoom and initialize exactly once per page over all four cycles (persistent counts 5→7→9→11→13 for two pages). This verifies script execution counts, not complete webNavigation event ordering during preload.

### Port lifecycle coverage in progress

New dedicated MV2/MV3 fixtures exercise actual runtime.connect ports, ordered bidirectional nested JSON/Unicode messages, sender frame metadata, explicit disconnect and disconnect when the production host disables the extension. These checks are pending exact-head CI. They do not establish service-worker suspension/wakeup or native-host messaging.

Port tests follow the [runtime.Port contract](https://developer.mozilla.org/en-US/docs/Mozilla/Add-ons/WebExtensions/API/runtime/Port). Firefox and Chrome differ when one of several receiving contexts unloads; the current single-recipient fixtures do not establish that multi-recipient behavior.

At `88483f8`, both port fixtures failed manifest validation because descriptions were missing; no port semantics were established. Corrected manifests are pending. New native-message framing/stdio components are also pending CI. They have no production delegate route or host-registration UI, so nativeMessaging remains blocked at installation.

At `3209fee`, corrected port fixtures pass 11/12 checks; MV2 disable-disconnect remains unobserved. Native-message framing/transport and manifest validation pass unit tests, including actual standard macOS processes, malformed/truncated input, deadlines and cancellation. The new registry/consent manager is not wired to production delegates or UI. Required nativeMessaging still rejects installation; no real native application compatibility is claimed.


The current continuation wires public WebKit native-message delegates to explicit host registration. Only verified CRX3 identities can use registered Chrome-format hosts; each invocation rechecks extension enablement, live context, nativeMessaging permission and the registered developer key. Users select an already installed executable's manifest and approve a native consent sheet. Registrations persist with owner-only permissions. Revocation, disable, removal and quit cancel owned processes; cleanup awaits child reaping. Limits are 1 MiB host responses, 64 MiB outbound messages/queue, eight buffered inbound messages, four connections per extension and sixteen overall; one-shot calls have a 30-second deadline. These limits are deliberate resource bounds and not full Chrome/Firefox conformance. Firefox allowed_extensions, unsigned identities, automatic browser-directory discovery, Safari native App Extensions and legacy formats remain unsupported. Actual options-page MV2/MV3 fixture execution and consent screenshots are pending exact-commit CI. Earlier bridge-only evidence is not production host evidence.


At `029feec`, [run 36780698616](https://github.com/super-original/serein-browser/actions/runs/36780698616) passes all 40 actual production native-host scenarios across options pages, MV2 backgrounds and MV3 workers, plus the independent live-port quit/child-reaping scenario. Consent and management captures were inspected ([images](evidence/2026-09-30/native-hosts/README.md)). Permission/registration revocation, regrant, disable/removal and scoped identity checks are exercised. These results supersede earlier pending integration notes for this limited CRX3/Chrome-format path. No Firefox host, native Safari format, arbitrary real native application, native-initiated reconnect or universal compatibility result is implied. All seven pinned real extensions still reject their separate missing API requirements.

Native tab folders do not implement the missing `browser.tabGroups` namespace. Folder hierarchy and controls are a browser feature; extension group APIs and exhaustive ordering/event semantics remain separate unfinished work.

### Packaged Safari Web Extensions (controlled verification)

The installer recognizes a selected `.appex` with `NSExtensionPointIdentifier = com.apple.Safari.web-extension`, `CFBundlePackageType = XPC!`, a bundle identifier, and a manifest under `Contents/Resources`. It retains the complete bundle and calls public `WKWebExtension(appExtensionBundle:)`, including WebKit’s resource validation. It does not flatten the bundle or normalize signed manifest bytes. Existing permission review, private exclusion, enable/disable and removal apply. Named native Safari App Extensions (`com.apple.Safari.extension`) and enclosing application packages receive an explicit unsupported-format error. Package copying additionally rejects nonregular/non-directory entries.

An original ad-hoc signed fixture tests actual installation/cancellation, options, MV3 worker messaging, storage after disable/reload, unchanged manifest bytes, removal, and tampered-bundle rejection. All 11 checks pass at `b3e2899` on actual macOS 27; installation screenshots were retrieved and inspected. No real Safari extension or App Store package has yet been verified. The fixture includes an inert native executable only to form a signable bundle; Serein does not load that executable. Safari `NSExtensionRequestHandling`, Safari-specific native messaging/containing-app integration, publisher trust/notarization policy, updates and runtime-ID equivalence remain unfinished or unsupported. Merely accepting a bundle is not full Safari compatibility.

### Tab creation and opener controlled verification

The host initializes requested pinned state, clamped index, opener and highlight state before publishing tab creation. Public parent-tab getter/setter callbacks support same-window opener relationships; self/foreign parents reject, closing a parent clears its references, and cross-window moves clear nonmoving openers. Native popups and Glance carry opener metadata too. Controlled MV2/MV3 tests inspect actual created-event payloads and create/get/update/duplicate behavior, including cross-window rejection. All 14 added checks pass at `4140bae` on macOS 27. Folder-visible ordering versus all-window extension indices and opener-change event delivery still require conformance work; this does not implement `tabGroups` or unblock the seven audited packages’ other missing API families.

### Firefox native-host continuation boundary

Mozilla's [native messaging contract](https://developer.mozilla.org/en-US/docs/Mozilla/Add-ons/WebExtensions/Native_messaging) identifies callers through `allowed_extensions` and the declared Gecko add-on ID. On macOS it passes two native arguments: the manifest path and add-on ID. Serein currently passes the Chrome origin and binds registration to a verified CRX3 identity. Firefox support is therefore unfinished host/package work, not established as a WebKit engine restriction: it needs add-on identity validation/binding, the alternate manifest schema, argument convention, consent and lifecycle tests. Merely accepting `allowed_extensions`, claiming signature verification from a declared ID, or sharing an existing Chrome registration would not establish compatible or safe behavior.

### October 1 unload-port investigation

At `32b17e3`, both fixtures first prove the expected fully loaded document and three echoes. Production `WKWebExtensionController.unload` succeeds; neither content-script port receives `onDisconnect` within five seconds. A retained content-script event listener still executes after unload, `postMessage` does not throw, and the echo count stays three. This is a measured compatibility failure; previous green disable checks did not reliably establish document readiness.

The [pinned upstream unload implementation](https://github.com/WebKit/WebKit/blob/ce5df19df1a0cd09a6aa8a5d46bcaf108aba692f/Source/WebKit/UIProcess/Extensions/Cocoa/WebExtensionContextCocoa.mm#L353) unloads background content and clears port maps. That source snapshot is **not proof of the shipping framework's exact implementation**, and background-page teardown may independently dispatch events. No public API for enumerating/disconnecting ordinary runtime ports was found in the exported controller/context interfaces; the native-message port delegate is a different API. An injected fake disconnect or forced page reload would not preserve real port semantics and unsaved page state. Engine investigation remains open; this does not classify unrelated host-implementable APIs as blocked.

### Pinned Gecko port-reference probe (pending)

A separate standard-runner workflow uses the same SHA-256-pinned Zen 1.22.2b binary as the visual baseline, in a fresh automation profile. It temporarily installs the original port fixture JavaScript, records source hashes, verifies three echoes, disables the actual add-on through its reference-browser add-on manager, and records disconnect/post-disable behavior with a desktop capture. This is reference automation only; no Gecko code or private API is added to Serein.

The MV2 manifest gains only a declared Gecko ID. The MV3 reference explicitly replaces Chrome's `background.service_worker` with Firefox's nonpersistent `background.scripts`; the modified manifest is retained in evidence, and this variant cannot establish Chrome worker lifecycle compatibility. [Mozilla's background documentation](https://developer.mozilla.org/en-US/docs/Mozilla/Add-ons/WebExtensions/manifest.json/background) describes this distinction. [Port lifecycle documentation](https://developer.mozilla.org/en-US/docs/Mozilla/Add-ons/WebExtensions/API/runtime/Port) also describes differing multi-recipient disconnect conditions. Serein's failing unload assertions remain intact while this reference is investigated; diagnostic workflow success means the scenario executed, not that Serein compatibility passed.


### Pinned Gecko port-disable comparison, October 1

[Reference run 36799509123](https://github.com/super-original/serein-browser/actions/runs/36799509123), exact source `25a1a70`, runs the original controlled `PortMessaging` content/background scripts in **Zen 1.22.2b** using a fresh profile. [Results and inspected desktop screenshots](https://github.com/super-original/serein-browser/actions/runs/36799509123/artifacts/11134623768) record three ordered echoes before the reference's actual add-on manager disables each extension (`userDisabled=true`, `isActive=false`). The original fixture page renders in both captures.

Neither MV2 nor MV3 produces the content-script disconnect marker after disable. Unlike Serein's system WebKit, Gecko also stops the retained DOM-event listener: the post-disable probe marker never appears and the echo count remains three. Serein's previous document-bound run leaves that listener callable, with `postError=none`, no disconnect marker and no new echo. The existing Serein disconnect assertion remains visible as a failure; its interpretation is now explicitly **a lifecycle conformance investigation, not a universal Firefox expectation established by that assertion alone**. This comparison does not justify synthesizing a disconnect event or ignoring retained script execution.

The reference adds a declared Gecko ID. Its MV3 manifest uses Firefox's nonpersistent background scripts in place of Chrome's service worker; both script bodies remain unchanged and their hashes are recorded. It is not evidence of Chrome worker equivalence. [Mozilla's Port documentation](https://developer.mozilla.org/en-US/docs/Mozilla/Add-ons/WebExtensions/API/runtime/Port) also documents different multi-recipient disconnect behavior between Firefox and Chrome; this fixture has only one recipient. Broader lifecycle, cross-extension and real-extension behavior remain unverified.


### Background network and cookie boundary scenarios (pending execution)

Original `Fixtures/ExtensionNetwork` MV2 persistent-page and MV3 worker fixtures exercise real background requests and `browser.cookies` operations. The HTTP fixture deliberately supplies no CORS grant. Checks cover denied → granted → revoked response access, redirects to a second explicitly denied/granted loopback hostname, actual background kind, cookie set/get/remove, normal website-store identity, private-store exclusion, host/API revocation and ordered change events. Cleanup deletes only the uniquely named fixture cookie and installed fixture record.

[Chrome's network model](https://developer.chrome.com/docs/extensions/develop/concepts/network-requests) distinguishes extension-origin fetch with host access from ordinary page/content-script CORS behavior. [Mozilla's cookies documentation](https://developer.mozilla.org/en-US/docs/Mozilla/Add-ons/WebExtensions/API/cookies) requires both the API permission and relevant host access. These are public engine scenarios, not a new native namespace shim. A denied response does not by itself prove that no HTTP request was sent; server logs retain that distinction. HTTPS, credentials, partitioned cookies, store/container IDs, session restart and arbitrary real extensions remain outside these narrow checks. Results must be recorded after exact-commit execution; no new API pass is claimed here.

At `7611908`, both new network fixtures were rejected before context creation because WebKit requires a nonempty manifest description. The follow-up supplies original descriptions; this is a fixture repair, not a passed network or cookies scenario. [MDN cookies.get](https://developer.mozilla.org/en-US/docs/Mozilla/Add-ons/WebExtensions/API/cookies/get) requires both cookies and host permission and specifies failure for absent host permission; the denied/revoked assertions remain strict.

### Pending extension consent lifecycle boundary

The native API-permission, match-pattern and URL-access delegates now require a live context and an existing normal window/tab before presenting consent and again before returning a grant. Disabling/replacing an extension or closing its requesting tab while the sheet is pending cancels authority. Background action popups and direct action dispatch also reject private windows. An original, background-free fixture invokes these production delegates with real NSAlert sheets: each of three prompt families checks live acceptance, disabled-context denial and replaced-context replay rejection, plus private-window and closed-tab cases. These are host-callback tests, not proof of JavaScript optional-permission event ordering. Results await CI.

### Network/cookie results at 21091e9

[Run 36804404567](https://github.com/super-original/serein-browser/actions/runs/36804404567) reaches all 15 cases per generation: MV2 11/15, MV3 12/15. Initial denied fetches fail, granted JSON and background kinds pass, and cookie set/get/remove uses the normal browser store without leaking to private windows. Revoking the API removes `browser.cookies` access. Immediate host revocation nevertheless still permits a readable fetch in both generations; MV2 additionally reads the redirect target despite its denied host, while MV3 rejects it. Cookie host revocation hides the cookie with null instead of a permission rejection, a semantic mismatch rather than observed cookie-value disclosure. Final cookie event arrays are empty. Additional bounded propagation and pre-revocation event checkpoints retain the original failing checks instead of silently relaxing them. Network access remains incomplete and requires further host/engine diagnosis.

### Additional real-package functional candidate

The official [uBO Lite 2026.930.1227 Firefox release](https://github.com/uBlockOrigin/uBOL-home/releases/tag/2026.930.1227) is pinned in the catalog: SHA-256 `aaa62dfbaa453b75315419ad3274fc3521c2236eb2478d0ebf3d4e7a35f2b769`, 9,634,550 bytes. It is an additional candidate, not a replacement for the seven rejected packages or for full uBlock Origin. Its unchanged EasyList rule 503 matches `/ads/!rotator/`; the original fixture server serves harmless JavaScript at that path and a nonmatching control. The scenario uses production loading/permission validation, grants only loopback host access, checks baseline/blocked/control/private/disabled/re-enabled execution and the original dashboard/background message protocol. Its install/data root is outside uploaded evidence, and no third-party package/code is committed or redistributed. Only source metadata and original harness code are published. Mozilla signing trust is not verified by this harness; byte identity is pinned. Actual results remain pending, and one passing rule would not prove complete blocker compatibility.

Public-source follow-up: [WebExtensionAPICookiesCocoa.mm](https://github.com/WebKit/WebKit/blob/main/Source/WebKit/WebProcess/Extensions/API/Cocoa/WebExtensionAPICookiesCocoa.mm) dispatches cookie change listeners without arguments and references [WebKit bug 267514](https://bugs.webkit.org/show_bug.cgi?id=267514) for missing changeInfo. This is a source-level explanation candidate, not proof of the installed binary's exact revision. The original fixture now records malformed event payloads separately rather than allowing an undefined payload to throw in its listener. It still requires real cookie identity, removed flag, cause and ordering; no event data is fabricated in the browser.

At `a16b46c` ([run 36805321909](https://github.com/super-original/serein-browser/actions/runs/36805321909)), all 12 native extension-consent cases pass. Network host revocation still allows response reads after the bounded retry interval in both generations; no cookie insertion event is recorded even before revocation. The new uBO Lite package loads in the audit, but only 6/9 functional-scenario checks pass: shipped-rule blocking, original options/background round trip and re-enabled blocking fail. Baseline, unmatched control, private exclusion and disabled resource loads pass. It is not marked compatible. Further diagnostics use public context background loading, context errors and getEnabledRulesets without modifying the package.

Asynchronous extension errors now have a native management-row surface, updated from public `WKWebExtensionContext.errorsDidUpdateNotification` and `errors`. A deliberately missing background module is an original fixture for detection, notification delivery, capture and disable cleanup. This production/UI change awaits CI; source [Apple errors documentation](https://developer.apple.com/documentation/webkit/wkwebextensioncontext/errors).

The uBO Lite investigation tests Firefox resource-origin semantics using public context.baseURL. The package's browser-flavor detection otherwise selects Chromium from the default `webkit-extension:` URL. At `50bc1e6` the main app exited during extension verification without aggregate results, so custom origins are being isolated in separately supervised controlled and real-package processes. Production installation retains default origins pending evidence; the original real package is unchanged. Native-host identity validation remains independent. Whether the custom origin resolves blocker failures or caused the exit is unverified.
