# Verification history

Historical checkpoints follow. “Pending” and “failed” describe the named commit at that time; use [current verification](VERIFICATION.md) for the latest state. No past failure is erased by a later fix.


## Repeated extension recovery and grids pass

`d4c80d1f865468b9d1e4f17b2f30bdd47d04df3a`, [run 36753951103](https://github.com/super-original/serein-browser/actions/runs/36753951103), passes **58 unit tests, 263/265 browser checks**, four independent quit checks and 12 bridge checks. All five initial/repeated extension recovery checks pass; each repeat preserves back-list count (2→2). Full URL-list/forward-position and zoom assertions are added next rather than assuming count equality proves complete restoration. Both remaining browser failures are the missing MV2/MV3 zoom events. Desktop rendering still fails independently. [App](https://github.com/super-original/serein-browser/actions/runs/36753951103/artifacts/11115558377), [evidence](https://github.com/super-original/serein-browser/actions/runs/36753951103/artifacts/11115813049).

Three/four-pane state, actual document ownership, focus, unload protection and pane closure pass. Both screenshots were inspected. Their rows are uneven (342/310 points), and columns have a one-point gap, unlike Zen. The follow-up uses a narrow public NSSplitView bridge for equal initial sizes/eight-point dividers and disables redundant safe-area insets in hosted page panes. Balanced/minimum-size regressions are pending. The fresh Zen grid in [run 36753946618](https://github.com/super-original/serein-browser/actions/runs/36753946618) was inspected: two equal columns, each with two 326-point-high panes.

Also pending: native keyboard command delivery, private-window exclusion, and a discoverable Commands menu in extension management.


## Find and extension window consent verified

`3556d1ec3d64b59427d36c5168f5bd1e485c21ba`, [run 36752879083](https://github.com/super-original/serein-browser/actions/runs/36752879083), passes 52 unit tests, **252/257 browser checks**, four independent quit checks and 12 bridge checks. All seven Find checks and eight MV2/MV3 window-close delegate checks pass; the latter test native delegate completion, not JavaScript promise semantics. Exact Find/error screenshots were retrieved and inspected. Initial extension options recovery passes this run, but all three repeated recoveries still fail, alongside two missing zoom events. Raw and customized views restore the failing host's exact opaque history successfully after a fresh resource load; this does not establish an engine history limitation. The follow-up preloads a recreated extension document before replacing its transient list with saved history, retaining count/recovery assertions. [App](https://github.com/super-original/serein-browser/actions/runs/36752879083/artifacts/11116075493), [evidence](https://github.com/super-original/serein-browser/actions/runs/36752879083/artifacts/11116285149). Desktop rendering remains failed.

Pending independent work: explicit selected-tab three/four-pane grids, legacy-session decoding and pane-close/workspace/focus/unload invariants. Zen's three-pane and incremental-fourth references were inspected in [run 36752869953](https://github.com/super-original/serein-browser/actions/runs/36752869953); a fresh four-pane grid capture is added separately because incremental addition preserves the prior layout.


## Native close and quit verified

`3b4cf1a267d8e3ae964a986a1f1d2e8f7d665439`, [run 36751909527](https://github.com/super-original/serein-browser/actions/runs/36751909527), passes 52 unit tests, **238/247 browser checks**, all four independent quit checks and 12 bridge checks. All five native window-close checks now pass. The supervised quit process exits with status zero and saves both tabs after fresh consent. Five Find checks pass (backward wrap, query replacement, empty result, old-tab result rejection, focus restoration); its first missing/existing-query checks fail. The follow-up ignores unchanged text-field binding writes, waits for field attachment in the fixture and reports actual callback values. Find's native screenshot was inspected; page content is still blank. The five extension-recovery and two zoom-event failures remain. [App](https://github.com/super-original/serein-browser/actions/runs/36751909527/artifacts/11114574215), [evidence](https://github.com/super-original/serein-browser/actions/runs/36751909527/artifacts/11114679098).

Pending: extension window-close completion now waits for real removal/cancellation; raw-view probes restore the failing host's exact opaque history; additional Zen three/four-pane references are requested.


## Exact-head recovery and consent results

`f9a4959eff9bff7221368b26367a443c0f82c815`, [run 36750626123](https://github.com/super-original/serein-browser/actions/runs/36750626123), builds and passes 52 unit tests, **232/240 browser checks** and all 12 bridge checks. Releasing old extension views does not fix the five recovery failures. Two zoom-event failures remain. Four window-consent checks pass, but the final accepted close does not remove the window; the follow-up closes directly after validated consent instead of issuing another close action during sheet dismissal. The separate quit test times out before producing results: its awaiting task cannot answer a modal termination loop. Its follow-up driver explicitly runs in modal and default run-loop modes. These fixes and Find query/tab/focus regression checks are pending. The exact-source Close Tab sheet and final recovery-error screenshots were inspected; desktop content still fails with zero glyph pixels. [App](https://github.com/super-original/serein-browser/actions/runs/36750626123/artifacts/11114697304), [evidence](https://github.com/super-original/serein-browser/actions/runs/36750626123/artifacts/11114921921).


Build follow-up: `8280880`, [run 36750196341](https://github.com/super-original/serein-browser/actions/runs/36750196341), failed compilation because the saved optional `pageZoom` is `CGFloat`, not `Double`. No runtime claims or app download are made for that commit. The type is corrected; downstream launch/render checks now require a successful build, while retaining their independent execution after runtime-scenario failures.

## Subframe boundaries verified; old-view lifecycle under test

`53d93bcfb41781a17c90437b817d268ccacdd74c`, [run 36749017621](https://github.com/super-original/serein-browser/actions/runs/36749017621), passes 52 unit tests, **228/235 browser checks** and 12 bridge checks. All six MV2/MV3 iframe origin/isolated-world checks pass. Both direct and preloaded history restoration pass in the isolated engine probe, so this is not evidence of a universal WebKit history failure. Five production-host recovery assertions and the two missing zoom events fail. The close-consent sheet and final error screenshot were retrieved and visually inspected. The next host change releases old extension views before unloading/recreating the context, retaining only opaque interaction state and zoom; full history/recovery assertions remain required. Window/quit consent tests are also pending. [App](https://github.com/super-original/serein-browser/actions/runs/36749017621/artifacts/11114530081), [evidence](https://github.com/super-original/serein-browser/actions/runs/36749017621/artifacts/11114545112). Actual desktop WebKit content still fails the rendering gate.

## Consent and zoom methods verified; restoration remains unresolved

`f3757e92445747a2de0d5703fc8024b704dc6cce`, [run 36747921197](https://github.com/super-original/serein-browser/actions/runs/36747921197), passes 52 unit tests, **220/225 browser checks** and 12 bridge checks on Xcode 27.1/macOS 27.0. Single and bulk close, unload replacement-document protection, cancellation and completion timing pass. MV2/MV3 `setZoom`/`getZoom` and zero reset pass; both missing `onZoomChange` checks fail. Pre-unload state capture preserves the history count but all three repeated options restorations still fail with error 102. A minimal same-context-identity engine probe now compares direct history restoration with restoration after a fresh document preload. [App](https://github.com/super-original/serein-browser/actions/runs/36747921197/artifacts/11113806272), [evidence](https://github.com/super-original/serein-browser/actions/runs/36747921197/artifacts/11113482322). Frame-origin fixtures are a separate pending verification workstream. Desktop rendering still fails.

## Xcode 27.1 verified; missing zoom event isolated

`17c03c2967cd1f2f121a56cf33a122c5ba607374`, [run 36746894298](https://github.com/super-original/serein-browser/actions/runs/36746894298), builds and passes 52 unit tests with Xcode 27.1 **27A9269**, Swift 6.4 and SDK/minimum 27.0 on macOS 27.0 **26A428**. Browser checks are **186/219**; 12 bridge checks pass. `tabs.onZoomChange` is undefined in both MV2/MV3, aborting the fixture before unrelated lifecycle assertions; the follow-up keeps the zoom event assertion failing but isolates its absence from other tests. Set/get/reset must be retested independently. Replacement navigation still appends history entries, so the next lifecycle fix captures settled interaction state before unloading the context rather than after engine invalidation. [App](https://github.com/super-original/serein-browser/actions/runs/36746894298/artifacts/11112269763), [evidence](https://github.com/super-original/serein-browser/actions/runs/36746894298/artifacts/11113700025). Same-workspace no-op and bulk actions pass. Desktop rendering remains failed.

## Bulk actions verified; reload history regression exposed

`e511f5808b88c04301f7c6f36bf315cbf9254ec5`, [run 36746025525](https://github.com/super-original/serein-browser/actions/runs/36746025525), passes 52 unit tests, 209/212 browser checks and 12 bridge checks. Bulk pin/unpin preserve selection and existing pinned reset URLs; workspace moves process the full selection. The selected pinned-tab screenshot was retrieved and inspected. Fresh requests recover both re-enabled options tabs and all three repeat cycles, but each cycle appends a history entry (4→5→6→7). The next change uses a replacement navigation and retains the history-count assertions. Zoom semantics and same-workspace no-op regressions are pending. [App](https://github.com/super-original/serein-browser/actions/runs/36746025525/artifacts/11112248795), [evidence](https://github.com/super-original/serein-browser/actions/runs/36746025525/artifacts/11112373500). Desktop content remains blank; no visual page-rendering success is claimed.

## Resource matcher verified; history handoff under test

`c336884173b093fdadeca5a757f3a3f721a3de51`, [run 36745209056](https://github.com/super-original/serein-browser/actions/runs/36745209056), passes 52 unit tests, 202/205 browser checks and 12 bridge checks. The adversarial wildcard regression passes. Raw and customized fresh views on the actual host context both load version 1.2; the initial re-enable checks also pass this run, but all three repeated history-bearing tab recoveries still fail. A fresh configuration alone is therefore insufficient to establish reliable recovery. The next change makes a fresh URL request after restoring a replaced context’s history instead of reloading its existing entry; duplicate-history behavior remains to be checked. Bulk pin/unpin/workspace actions and their runtime regressions are also pending. [App](https://github.com/super-original/serein-browser/actions/runs/36745209056/artifacts/11112237901), [evidence](https://github.com/super-original/serein-browser/actions/runs/36745209056/artifacts/11112013352). Desktop rendering remains failed.

## Focus verified; host reload failure isolated

`b4687ac647ebc2380e2d54994e1896e7f2388114`, [run 36744220479](https://github.com/super-original/serein-browser/actions/runs/36744220479), passes 51 unit tests, 198/203 browser checks, and 12 bridge checks. Native address submission and extension-origin handoff retain content focus. All three isolated extension options probes (fresh, reload, restricted reload) pass. The five production-host recovery checks still fail; restricted permissions alone do not reproduce the failure. The actual error screenshot was retrieved and inspected: native “Unable to load page / Frame load interrupted” and Reload controls are legible; this is not a rendered extension page. Follow-up probes compare raw and customized configurations on the failing host context. Resource glob matching now avoids regex backtracking, with an adversarial-pattern regression awaiting CI. [App](https://github.com/super-original/serein-browser/actions/runs/36744220479/artifacts/11111169508), [evidence](https://github.com/super-original/serein-browser/actions/runs/36744220479/artifacts/11111104638). The desktop-rendering gate still fails; full completion remains unmet.

## Reload-cycle follow-up

`744bfc439a51c92b3094af7c8032e999ec07876f`, [run 36738592788](https://github.com/super-original/serein-browser/actions/runs/36738592788), passes 51 unit tests and 12 bridge checks, with **192/197 browser checks passing**. Removing the cancel/reload sequence did not resolve extension-page recovery: the same two recovery checks and all three repeat cycles fail with error 102, after an allowed, displayable `text/html` response. This rules out a simple MIME rejection; it does not establish the root cause. A distinct-controller probe now separates fresh load, reload, and reload with revoked tab/site permissions. Native focus handoff is an independent implementation/test follow-up. [App](https://github.com/super-original/serein-browser/actions/runs/36738592788/artifacts/11109212002), [evidence](https://github.com/super-original/serein-browser/actions/runs/36738592788/artifacts/11109226968). Desktop rendering still fails.

## Native keyboard completion and reload diagnosis

`4eb830bd4325ebc0ded68a61473d9cdbb56e49de`, [run 36737582637](https://github.com/super-original/serein-browser/actions/runs/36737582637), passes **51 unit tests, 192/194 browser checks and 12 bridge checks**. Up preserves the typed query and text editor; Escape dismisses suggestions without losing editing focus; reopening and Return navigate to the selected local result. The native highlighted-suggestion screenshot was inspected. Both extension re-enable failures persist as WebKit error 102. Traces show the correct context and host allow decision before failure. The next change avoids cancel/reload after interaction-state restoration, skips empty history restoration, and exercises three re-enable cycles. [App](https://github.com/super-original/serein-browser/actions/runs/36737582637/artifacts/11108356256), [evidence](https://github.com/super-original/serein-browser/actions/runs/36737582637/artifacts/11108301286). Desktop rendering remains failed.

## Resource boundaries and recovery diagnostics

`7e881c6968b4962650ed8fe62b913d9894a69c2b`, [run 36736623545](https://github.com/super-original/serein-browser/actions/runs/36736623545), passes **51 unit tests, 190/192 browser checks and all 12 bridge checks**. Actual MV2/MV3 public resource navigation, MV3 unmatched-origin denial and website-to-private-options denial pass. Native keyboard suggestion selection passes again, and the selected-suggestion screenshot was retrieved and inspected. Both re-enable recovery checks still fail with `Frame load interrupted`; their saved destination is intact, so destination loss alone does not explain the failure. Bounded policy/error tracing and removal of an obsolete test-held view reference are the next diagnostic changes. [Candidate app](https://github.com/super-original/serein-browser/actions/runs/36736623545/artifacts/11107343322), [evidence](https://github.com/super-original/serein-browser/actions/runs/36736623545/artifacts/11107103393). The desktop content gate still fails.

## Address keyboard verification and recovery regression

Source `9f92de0696b5afd64a9006304b6930af7066ec85`, [run 36735423590](https://github.com/super-original/serein-browser/actions/runs/36735423590), passes 47 unit tests and **183/185 browser checks**. Actual Command-L/type/Down/Return input selects and loads the local suggestion. The retrieved `24-address-keyboard-suggestion.png` visibly shows the selected suggestion and retained text-field focus. The two failures are options recovery after re-enable and recovery of a tab opened before context availability; these passed on the preceding source, so their reliability remains unresolved. Follow-up preserves intended destinations during restoration and adds diagnostic state; it must pass its own runtime checks. The independent desktop gate still fails. [Candidate app](https://github.com/super-original/serein-browser/actions/runs/36735423590/artifacts/11105984816), [evidence](https://github.com/super-original/serein-browser/actions/runs/36735423590/artifacts/11106673493).

## Latest signed-update verification

Source `835870b191ca6acd29839884c0ce70f73c49954c`: [run 36731114526](https://github.com/super-original/serein-browser/actions/runs/36731114526) passed **47 unit tests, 171 of 172 browser checks, and all 12 isolated bridge checks**. Same-developer signed updates, permission review/cancellation, downgrade/wrong-key/unsupported-permission rejection, persistent identity/storage, disabled updates and retained site denial passed. The sole browser failure was the open options document remaining empty after update. The native update-consent screenshot was retrieved and inspected. [Candidate app](https://github.com/super-original/serein-browser/actions/runs/36731114526/artifacts/11104888183) is ARM64/macOS 27, ad-hoc signed, not notarized; it includes that known defect.

Follow-up `237cd3dfe2e857c3986eba76436ab06e8cc6dbb6` uses the public extension document configuration and adds origin/history checks in [run 36733548661](https://github.com/super-original/serein-browser/actions/runs/36733548661). All **47 unit tests, 178 browser checks and 12 isolated bridge checks passed**. Initial options loading, updated document contents, ordinary/extension navigation and native Back/Forward passed. The consent and native error screenshots were retrieved and inspected. [Exact-source app](https://github.com/super-original/serein-browser/actions/runs/36733548661/artifacts/11106630883) and [evidence](https://github.com/super-original/serein-browser/actions/runs/36733548661/artifacts/11106386618). The desktop-rendering gate still fails with zero content pixels. Follow-up `1748c81969a05a3b5d778366d4f16b99ce86a1a2`, [run 36734574259](https://github.com/super-original/serein-browser/actions/runs/36734574259), passed **47 unit tests, all 183 browser checks and all 12 bridge checks**. Re-enable refresh, recovery of pages opened before context availability, page-initiated origin navigation and JavaScript Back with forward-history preservation pass. Its native update screenshot was inspected and shows the options title. [App](https://github.com/super-original/serein-browser/actions/runs/36734574259/artifacts/11106238206) and [evidence](https://github.com/super-original/serein-browser/actions/runs/36734574259/artifacts/11106193382). Desktop rendering still fails. Full original-spec completion remains the goal, not a claim made by these fixtures.

## Signed package and adapter continuation

Source `b854f846c3b6c8198a6103845ed930e9c7dd49f3`: [run 36723768551](https://github.com/super-original/serein-browser/actions/runs/36723768551) passes **39 unit tests, 144 browser checks and 12 isolated bridge checks**. CRX3 RSA/P-256 proof verification, invalid proofs/tampering, bounded decompression/checksums, path aliases, actual installation consent/loading and persisted archive identity pass. The native consent capture (`runtime/22-crx3-install-consent.png` in the evidence artifact) was retrieved and inspected. Missing namespace installation works in both the MV2 background page and actual MV3 service worker, without bypassing native-message permission denial. No production downloads API adapter has been enabled.

[Download this tested ARM64/macOS 27 app](https://github.com/super-original/serein-browser/actions/runs/36723768551/artifacts/11102502761); ad-hoc signed/hardened, not notarized. [Evidence and real screenshots](https://github.com/super-original/serein-browser/actions/runs/36723768551/artifacts/11102272804). The unchanged actual-desktop gate still fails with zero dark content pixels; full extension compatibility and the original completion goal remain unmet. Follow-up `f7ef3618976f97be5da2fd79854c693e0bddd030` [run 36724793938](https://github.com/super-original/serein-browser/actions/runs/36724793938) passed 39 unit tests, all 146 browser checks and all 12 bridge checks. The content script reports the verified developer ID as runtime.id; persistence and removal pass. Its consent screenshot was inspected. [Exact-source app](https://github.com/super-original/serein-browser/actions/runs/36724793938/artifacts/11102313816) and [evidence](https://github.com/super-original/serein-browser/actions/runs/36724793938/artifacts/11102083848) retain the failed desktop-rendering gate.


This browser is not complete. A passing build is not a production or extension-compatibility claim.

## Earlier verified source

Exact source `8245e2a985ea5e270538df7f7227523b0b294668`: [run 36719782728](https://github.com/super-original/serein-browser/actions/runs/36719782728) passed **33 unit tests, all 140 browser runtime checks, and all 8 isolated native-message checks**. The overall workflow fails solely at the unchanged actual-desktop gate: 0 dark content pixels, required >1000. [Download this ARM64 application](https://github.com/super-original/serein-browser/actions/runs/36719782728/artifacts/11097717919), macOS 27 minimum, ad-hoc signed/hardened, not notarized; artifact expires October 14. [Raw evidence](https://github.com/super-original/serein-browser/actions/runs/36719782728/artifacts/11097702508) expires October 7.

New verified scope includes native Save-panel keyboard destination selection, exact path/bytes and cancellation; in-memory download resume/private ownership; command/range multiselection and bulk close; MV2/MV3 per-tab highlighting/query/event behavior; extension queries preserving an unloaded tab; and stale tab/document navigation-confirmation rejection. The fixture workload is serialized, so these are not concurrent event-ordering claims. `tabs.highlight` remains absent. The isolated native-message transport verifies denial/grant/context-bound reply and unknown-application rejection; production native messaging and browser API adapters remain unavailable.

Exact-source Save-panel, network-error and multiselection desktop captures were retrieved through the connected GitHub artifact reader and visually inspected. The error destination and native Reload UI are visible; the Save sheet shows the requested filename/folder; native multiselection is visible. Web content remains blank. See [retained captures](evidence/2026-09-30/README.md).

Diagnostic performance for this run: startup to fixture check 2.82 seconds; full integration workload median summed RSS 348.21 MiB, peak 409.31 MiB over 20 samples; warm idle median 362.11 MiB and 0.10% interval CPU over 10 seconds, including app/WebKit processes. RSS can double-count shared pages, VM hardware differs from physical Macs, and blank rendering invalidates representative browsing/energy claims. These measurements do not establish a performance improvement.

## Earlier continuation checkpoint

`cfc333d` [run 36717038331](https://github.com/super-original/serein-browser/actions/runs/36717038331) passed 33 unit tests and recorded **136/138 passing browser checks before the native-message experiment**. Native Save-panel keyboard selection, exact destination/content, cancellation and stale tab/document navigation confirmation passed; the Save-panel screenshot was inspected. Both extension multiselection query assertions failed. The isolated probe then terminated during fixture loading without final results; it is being moved into a separate process/required CI step. This checkpoint does not replace a fully passing runtime run or establish native-message support. The real desktop gate remains failed. Current-head results and downloadable baseline are distinguished in [draft PR #1](https://github.com/super-original/serein-browser/pull/1).

## Baseline audit (2026-09-30)

The saved checkout and remote `main` both resolve to `8fcac24225c0cee2dde32ae0b5b8649bc2ee1706`. There were no open or closed PRs and no newer build runs at audit time. The September 17 [run](https://github.com/super-original/serein-browser/actions/runs/35246339695) passed build/unit/package and integration steps but failed **Gate actual desktop rendering**. Its diagnostic artifact has expired; the app artifact is not being preserved as requested. A fresh [baseline run](https://github.com/super-original/serein-browser/actions/runs/36704547843) passed all 43 app scenarios but reproduced the rendering failure on macOS 27 `26A428`.

Implemented code and prior evidence cover navigation, basic tabs/workspaces, two-pane splits, persistence, private data stores, downloads and a limited system-WebKit extension host. See [Zen parity](ZEN_PARITY.md) and [extension scope](EXTENSIONS.md); their partial/unsupported entries remain requirements.

## Prioritized backlog

| Priority | Work | Evidence / completion bar |
|---|---|---|
| P0 | Establish actual page rendering | Inspect fresh desktop and direct-AppKit captures; retain the failing gate until genuine page rendering passes. Do not replace desktop evidence with WebKit snapshots. |
| P0 | Site permission policy | Implemented and exercised: exact-origin/capability policies, private isolation, settings/reset and stale-prompt protection. Real hardware capture/location consent remains unverified. |
| P1 | Session/split lifecycle | Focus/close/workspace/restore regressions fixed and tested; active-pane geometry inspected. Full split groups, window history stacks and broader AX interactions remain gaps. |
| P1 | Native interaction and Zen comparisons | Inspect matched light/dark, compact, split and settings states; expand keyboard/AX and accessibility coverage. |
| P1 | Extension semantic coverage | Package-loading audits are not functionality tests. Implement/test lifecycle, host APIs and permission boundaries; retain native Safari/CRX/legacy restrictions explicitly. |
| P2 | Durable downloads, suspension, richer Zen parity | Normal download history and in-memory resume are implemented; cross-launch resume, automatic media/unsaved-state-aware suspension, Glance, groups/folders, profiles, import and sync remain absent or partial. |
| P2 | Distribution and performance | App is ad-hoc signed, not notarized; measure subprocess resources after reliable rendering. No paid runner or local Mac work. |

## Evidence conventions

CI records runtime/SDK/compiler/architecture and Mach-O deployment target. App integration checks are in-process scenarios, except explicitly labeled native keyboard checks. Capture existence and DOM/title checks do not prove rendered content. The glyph-presence gate detects a blank-page regression; it does not establish Zen fidelity or accessibility. Site-permission store checks do not prove physical camera, microphone or location delivery on a hosted VM.


## Verified continuation

[Run 36706449602](https://github.com/super-original/serein-browser/actions/runs/36706449602) tests commit `ea3a4a0d4416c86033ad38094e30ef388ce6e5b1`: **26 unit tests and all 65 actual-app integration checks pass**. Release packaging/signature/deployment checks pass. The overall workflow correctly **fails** the desktop rendering gate (`darkContentPixels: 0`, required >1000).

Verified new scope: exact-origin/capability policy separation, combined media decisions, persistence/reset, private-normal and private-private isolation, native consent-sheet presentation, Allow Once without persistence, stale prompt rejection, split focus/state preservation, required extension permission admission, production disable/remove paths and local-storage reset after reinstalling MV2/MV3 fixtures under the identical UUID. Both fixture counters restart at 1. In-process sheet responses do not establish AX consent automation or physical camera/microphone/location delivery.

The same run's warm-idle diagnostic samples **314.99 MiB summed RSS** and **1.11% interval CPU** over 9 seconds, including the app and WebKit subprocesses. Conditions include the deterministic fixture, several tabs, and a hidden diagnostic WebKit window. RSS may double-count shared memory; CPU includes processes present at both sample endpoints. Failed desktop rendering invalidates a normal browser workload comparison. These are diagnostic measurements, not performance or energy claims.

The [platform probe](https://github.com/super-original/serein-browser/actions/runs/36705841148) proves the same blank-page defect in system Safari and an unhardened WKWebView witness. [All 14 refreshed Zen references](https://github.com/super-original/serein-browser/actions/runs/36705707876) were visually inspected; the same fixture renders in Zen. [Retained inspected comparisons](evidence/2026-09-30/README.md) show the evidence directly.

Native permission settings and consent sheets were inspected, as were focused primary/secondary split outlines. Inspection found an extra titlebar-safe-area inset inside native split panes. [Run 36707376209](https://github.com/super-original/serein-browser/actions/runs/36707376209), exact commit `acf9bebd0d6f03ed2104b27af47a0bfe48f87951`, passed the same 26 unit and 65 app checks. Its inspected captures confirm the corrected eight-point page inset and focus outline moving between panes. Web content is still blank and the rendering gate still fails.

Full extension compatibility remains unmet: all seven pinned real packages are rejected for exact reasons in [the current matrix](EXTENSIONS.md#current-real-package-admission-results). Safari native/legacy formats and unsupported engine API semantics have not been implemented. Full Zen parity, accessibility states, media/device behavior, crash injection, normal-workload performance and signed/notarized distribution remain release blockers. No claim that independent backlog items are complete is implied by the platform failure.


The error-state capture also exposed a recovery defect: failed navigation could show the previous committed URL, and Reload could reload that old page. The continuation now retains provisional/failed destinations, routes toolbar/menu/error-button reload through the failed target, and adds explicit failed-address/retry scenarios. Download responses clear provisional navigation state instead of replacing the current tab destination. Latest exact-commit results are recorded in [draft PR #1](https://github.com/super-original/serein-browser/pull/1); the prior verified runs above are kept as historical evidence.

Commit `105b9f5cdfc9482cf8f3ec1a3eceb6cfc24e3679`: [run 36707859265](https://github.com/super-original/serein-browser/actions/runs/36707859265) passed 26 unit tests and all 67 runtime checks, including failed-destination retention and retry. The actual desktop gate still fails. The inspected [network-error screenshot](evidence/2026-09-30/navigation-error.png) shows the unavailable destination in the address field and native recovery UI. [Download this tested ARM64 application](https://github.com/super-original/serein-browser/actions/runs/36707859265/artifacts/11091774981); ad-hoc signed, not notarized, macOS 27 minimum, rendering failure unresolved.

The next permission follow-up, `0b6623b`, passed all 73 runtime checks in [run 36708785208](https://github.com/super-original/serein-browser/actions/runs/36708785208), including persisted extension revocation and restored denied-host injection for MV2/MV3. The rendering gate remained failed. A subsequent unload guard also protects the unfocused primary split pane and revalidates visibility after confirmation; exact-head CI will verify these regressions.

`41f6261` passed 28 unit tests and 88 runtime checks in [run 36709589360](https://github.com/super-original/serein-browser/actions/runs/36709589360): visible split-pane unload protection, confirmation-time selection revalidation, and actual MV2/MV3 tabs create/get/duplicate/remove with pinned state, URL/identity and created/removed events. The selected split desktop capture was inspected. `74977b2` [run 36709877579](https://github.com/super-original/serein-browser/actions/runs/36709877579) additionally verifies workspace address/selection synchronization and automatic permission-notification persistence. The desktop rendering gate remains failed. A reviewable [upstream rendering report](MACOS27_RENDERING_REPORT.md) is prepared but has not been posted.

Download follow-up under verification: production WKDownload delegate/store, durable normal history, explicit interrupted state after relaunch, progress, in-memory pause/resume when WebKit supplies resume data, private-window record ownership and closure cleanup. A slow deterministic HTTP Range fixture verifies real resumption and full byte integrity. Destination selection is injected in these integration cases; native Save-panel automation and resume across application launches are not claimed.

`4302e2c` [run 36712466648](https://github.com/super-original/serein-browser/actions/runs/36712466648) passed 30 unit tests and all 115 runtime checks. The production download store/delegate completed and restored normal history, isolated private owners, excluded private records from disk, retired an active private download on window closure, paused/resumed an actual 8 MiB range-capable transfer with full byte integrity, rejected resumption through a private context, and discarded paused resume state on cancellation. The desktop rendering gate still failed.

### Credential-free saved browsing URLs

Source inspection found raw URL userinfo could be saved in history, bookmarks, open tabs, pinned home URLs and closed-tab restoration. Those persistence boundaries now remove usernames/passwords while retaining path/query/fragment and leaving a live navigation value unchanged. Legacy libraries are sanitized and rewritten when loaded; legacy sessions are sanitized before use and on subsequent saves. URL-shaped fallback titles are sanitized when equal to the original URL. This is not a general query-string/title secret detector. Unit tests cover saved open/pinned/closed tabs and private exclusion; actual-app store checks exercise legacy migration, deduplication, private/non-web exclusion and reload. Source `053ba6d6d4b9da3066cfbab1f954418a54637f4e` [run 36726032188](https://github.com/super-original/serein-browser/actions/runs/36726032188) passes 42 unit tests, all 151 browser checks and all 12 isolated bridge checks. The exact-source light desktop was inspected and remains blank in WebKit content. [App](https://github.com/super-original/serein-browser/actions/runs/36726032188/artifacts/11103206361) and [evidence](https://github.com/super-original/serein-browser/actions/runs/36726032188/artifacts/11103026400).

### Single-parser archive extraction

The package host now streams only validated central/local UTF-8 entry names and stored/deflate payloads into a newly created private destination. It no longer hands a checked ZIP to a second extractor that could interpret extra fields differently. Exclusive no-follow file creation prevents replacement; failed extraction removes only its newly owned destination. Existing destinations are preserved. Alternate Unicode-name extra fields and filesystem metadata (ownership, resource forks, modes, links) are not applied. This is an explicit format limit, not full arbitrary ZIP compatibility. A fixture with a Unicode extra path naming `../outside.json` must create only the validated `manifest.json`; an existing destination must remain unchanged. Exact source `0f8de08062adb6b81685b7d422e78ba1424f9dbd` [run 36727152097](https://github.com/super-original/serein-browser/actions/runs/36727152097) passes 43 unit tests, all 151 browser checks and all 12 bridge checks; all seven real packages reach the same required-API rejections. Exact consent/error captures were inspected. [App](https://github.com/super-original/serein-browser/actions/runs/36727152097/artifacts/11103522156) and [evidence](https://github.com/super-original/serein-browser/actions/runs/36727152097/artifacts/11103667129). The desktop gate still fails.

### Signed update lifecycle (verification pending)

The next source adds same-developer/newer-version CRX3 updates, explicit permission review, preserved enabled state/data/identity, immutable package directories and an atomic registry commit. Public WebKit resource origins are persisted and loaded extension pages reload after update. Per-extension operation locks also prevent enable/remove/update overlap and stale array-index writes. Controlled original fixtures cover rejection, cancellation, permission additions/revocation, disabled update/re-enable, storage preservation and options-page version changes. CI results remain pending.

### Close and unload consent follow-up (pending verification)

Single/bulk close and manual unload now bind confirmation to the captured document identity. A navigation or runtime replacement while the native sheet is open invalidates the old consent. Extension tab-close completion follows actual removal and reports cancellation rather than resolving before the user's decision. Runtime scenarios exercise pending completion, cancellation, replacement documents, bulk close, and unload. Existing form-input detection remains partial; this does not claim complete beforeunload or arbitrary application-state detection.

### Window and application consent follow-up (pending verification)

Window closure and application quit now compare the complete tab/document snapshot captured when consent was requested. Window approval uses a one-shot close flag instead of clearing edit flags. Native window scenarios cover new-tab invalidation, cancellation and fresh approval. A separate supervised app launch exercises actual `NSApplication.terminate` cancellation, stale approval and final accepted exit; its own CI gate requires exit status 0 and persistence of both current tabs. This keeps an unexpected quit from erasing the main browser suite. The harness terminates only its directly launched fixture process on timeout.


## Inert-preload diagnostic checkpoint, September 30

### Source and results

`502207897435bffb51d1a3099e9516b9c06e1b09`: [run 36758205114](https://github.com/super-original/serein-browser/actions/runs/36758205114) passes **58 unit tests, 291/303 browser checks, four independent quit checks and 12 bridge checks**. Actual environment: macOS 27.0 26A428, Xcode 27.1 27A9269, Swift 6.4, SDK/minimum 27.0, ARM64.

[Download app](https://github.com/super-original/serein-browser/actions/runs/36758205114/artifacts/11117407734) · [Evidence](https://github.com/super-original/serein-browser/actions/runs/36758205114/artifacts/11117227944). Ad-hoc signed/hardened; not Developer ID signed or notarized. Development candidate with known defects.

Previously verified at `21be7ae`: complete back/forward URL-list, current-position and zoom preservation across initial and three repeated extension recoveries; seven Find checks; eight extension-window close delegate checks; native window/quit consent with process exit/session save; selected-tab grids, balanced divider geometry, minimum-window bounds, focus, unload protection and closure. Actual keyboard commands, management-menu dispatch and private-window exclusion pass for MV2/MV3. These narrow fixtures do not establish universal extension compatibility.

The twelve browser failures include missing MV2/MV3 `tabs.onZoomChange`, two populated-window `about:blank` URL assertions (one tab is returned, but its URL is empty), one intermittent Find focus failure, three repeated recovery failures from the inert-preload experiment, and four initialization-count checks. The latter incorrectly used old signed archives; regenerated archives are required to exercise the counters. The final recovery error screenshot was retrieved and inspected. Prior real-resource recovery at `21be7ae` passed history/zoom checks, but duplicate script initialization was unmeasured. Window creation, size-only bounds, resizing, focus, removal, private-denial and created/removed events pass through actual MV2/MV3 JavaScript APIs. The separate **actual desktop rendering gate fails** with zero content glyph pixels. DOM/internal snapshots are not desktop-rendering evidence. Plain WKWebView and Apple-signed Safari reproduce IOSurface failures on this free runner. No supported second free macOS 27 image has been identified; no private flags, security weakening, lower deployment target or engine substitution is used. [Prepared upstream report](MACOS27_RENDERING_REPORT.md) has not been posted.

Grid, minimum-window and extension-management screenshots were inspected. Native grid columns now have eight-point gaps, with 327/326-point rows. [Side-by-side original screenshots and measurements](evidence/2026-09-30/grid/README.md) compare the inspected fresh Zen reference; their sidebar/focus differences are explicit. Page bodies remain blank.

### Follow-up at the time

Pending follow-up: real-resource preload with public per-navigation JavaScript suppression, regenerated signed fixtures/counters, Find focus restoration after view removal, and granted-HTTP populated-window coverage while retaining the failing `about:blank` assertion. Cross-launch normal-download resume persistence and a two-process byte-integrity/privacy gate require a fresh exact-head run.


## Glance first runtime checkpoint

`71983bc54705b0dbd5b9ecbc7211970123f94f3d`: [run 36762956337](https://github.com/super-original/serein-browser/actions/runs/36762956337) passes **66 unit tests, 318/328 browser checks, ten independent download-restart checks, four independent quit checks and 12 bridge checks**. Actual environment: macOS 27.0 26A428, Xcode 27.1 27A9269, Swift 6.4, SDK/minimum 27.0, ARM64.

[Download app](https://github.com/super-original/serein-browser/actions/runs/36762956337/artifacts/11118984772) · [Evidence](https://github.com/super-original/serein-browser/actions/runs/36762956337/artifacts/11119483976). Ad-hoc signed/hardened; not Developer ID signed or notarized. Development candidate with known defects.

Normal paused downloads resume in a new app process with full 8 MiB byte integrity. Private resume data/history stay off disk; owner-only file permissions and completion/cancellation cleanup pass. Active downloads without saved resume data still become interrupted. The inspected Downloads screenshot now describes this relaunch behavior correctly.

Extension recovery passes complete back/forward URL-list, current-position and zoom preservation, plus exactly one options-script initialization per page across initial and three repeated cycles. Public navigation preferences suppress scripts during the transient real-resource preload. Find checks including actual Command-F, query entry, Escape and subsequent web-page key delivery, native/extension-window consent, actual quit/session saving, balanced four-pane grids, minimum-window bounds and keyboard/menu extension commands pass. Window lifecycle and populated URLs for granted HTTP pages pass through MV2/MV3 JavaScript APIs.

Six Glance checks fail: actual Option-click, both tab-cycling directions, expand-state preservation, Escape and returned page-key delivery. Geometry, minimum-window control bounds, same-store loading, edit-consent invalidation, live normal-window movement, split conversion and private isolation pass. Both Glance screenshots were retrieved and inspected. The four other browser failures are missing MV2/MV3 `tabs.onZoomChange` and empty `about:blank` URLs in populated-window results. The separate **actual desktop rendering gate fails** with zero content glyph pixels. DOM/internal snapshots are not desktop-rendering evidence. Plain WKWebView and Apple-signed Safari reproduce IOSurface failures on this free runner. No supported second free macOS 27 image has been identified; no private flags, security weakening, lower deployment target or engine substitution is used. [Prepared upstream report](MACOS27_RENDERING_REPORT.md) has not been posted.

Downloads and extension-management screenshots from this exact commit were retrieved and inspected. Earlier inspected native-grid geometry has eight-point column gaps and 327/326-point rows. [Side-by-side original screenshots and measurements](evidence/2026-09-30/grid/README.md) compare the pinned Zen baseline with explicit focus/sidebar differences. WebKit page bodies remain blank.

## Current work under verification

Follow-up routes browser shortcuts before WebKit event handling, uses actual CoreGraphics pointer events, diagnoses the expand-state assertion, and restores a closed owner's preview relationship. The owner underlay now uses the pinned source's 0.97 visual scale and 0.3 opacity rather than resizing its web viewport. These changes await exact-head verification. Full original-spec completion remains the goal.


## Pre-native-lifecycle checkpoint notes

# Verification and continuation backlog

Full original-spec completion remains the goal and is not achieved. [Draft PR #1](https://github.com/super-original/serein-browser/pull/1) is unmerged. [Historical checkpoints](VERIFICATION_HISTORY.md) retain previous results and failed experiments.

## Latest verified source

`3209fee9e111dfa4b9c2bebacc84543bd07bfe23`: [run 36776390262](https://github.com/super-original/serein-browser/actions/runs/36776390262) passes **91 unit tests, 371/385 browser checks, 12 independent download-restart checks, four independent quit checks and 12 bridge checks**. Actual environment: macOS 27.0 26A428, Xcode 27.1 27A9269, Swift 6.4, SDK/minimum 27.0, ARM64.

[Download app](https://github.com/super-original/serein-browser/actions/runs/36776390262/artifacts/11125864941) · [Evidence](https://github.com/super-original/serein-browser/actions/runs/36776390262/artifacts/11126241608). Ad-hoc signed/hardened; not Developer ID signed or notarized. Development candidate with known defects.

Normal paused downloads resume in a new app process with full 8 MiB byte integrity. Private resume data/history stay off disk; owner-only file permissions and completion/cancellation cleanup pass. Active downloads without saved resume data still become interrupted. The inspected Downloads screenshot now describes this relaunch behavior correctly.

Extension recovery passes complete back/forward URL-list, current-position and zoom preservation, plus exactly one options-script initialization per page across initial and three repeated cycles. Public navigation preferences suppress scripts during the transient real-resource preload. Find checks including actual Command-F, query entry, Escape and subsequent web-page key delivery, native/extension-window consent, actual quit/session saving, balanced four-pane grids, minimum-window bounds and keyboard/menu extension commands pass. Window lifecycle and populated URLs for granted HTTP pages pass through MV2/MV3 JavaScript APIs.

All 19 existing Glance checks pass, including actual Option-click, both Control-Tab directions, Escape, returned page-key delivery, live expansion/split/movement, consent, private isolation and reopened relationships. All new popup checks pass: the reopened owner attaches at 756×661, a real external-host link opens the essential's preview, its store is shared correctly, its native message controller is distinct, and closing it preserves parent edit tracking. The `c136b59` capture 34 was inspected and shows the actual preview and essential badge. Unprimed ordinary/Glance fullscreen entry still fails with InvalidStateError despite trusted input and active user activation. A standard WebGL context succeeds, after which native fullscreen entry and Escape pass (four checks); the later WebGPU scenario also passes four checks, but its adapter request returns null and may inherit WebGL initialization. Twelve of 39 process samples now contain WebKit.GPU. All four GPU-probe screenshots were retrieved and inspected: ordinary page bodies remain white and fullscreen captures are black. Native state/DOM fullscreen success does not prove rendered fullscreen content. The nine unprimed fullscreen failures remain. All 12 bridge checks pass. The four other browser failures are missing MV2/MV3 `tabs.onZoomChange` and empty `about:blank` URLs in populated-window results. The separate **actual desktop rendering gate fails** with zero content glyph pixels. DOM/internal snapshots are not desktop-rendering evidence. Plain WKWebView and Apple-signed Safari reproduce IOSurface failures on this free runner. No supported second free macOS 27 image has been identified; no private flags, security weakening, lower deployment target or engine substitution is used. [Prepared upstream report](MACOS27_RENDERING_REPORT.md) has not been posted.

Downloads and extension-management screenshots from the preceding `4449c7a` checkpoint were retrieved and inspected. Earlier inspected native-grid geometry has eight-point column gaps and 327/326-point rows. [Side-by-side original screenshots and measurements](evidence/2026-09-30/grid/README.md) compare the pinned Zen baseline with explicit focus/sidebar differences. WebKit page bodies remain blank.

## Current work under verification

Fresh-process checks at the verified source isolate baseline, WebGPU-first and WebGL-first. **8/12 pass**: both API primers permit native/DOM entry and Escape, while all four unprimed baseline checks fail. WebGPU still returns no adapter, but both primers create a GPU process; baseline has none. All five captures were inspected: both fullscreen images are black and ordinary pages blank. This narrows the fullscreen prerequisite without solving desktop rendering. No production warmup is introduced.

Private app-record persistence and signed-update registry permissions pass, including failed-publication cleanup and symlink replacement. All four geometry unit cases and all four actual window-placement/fullscreen/save/exit checks pass. The retrieved exit screenshot was inspected and shows the correct 800×500 window.

All 12 ordinary-tab suspension checks now pass with a nonempty back/current/forward setup: both cycles release the old view, retain history and zoom, and subsequent Forward works. All six MV2/MV3 extension-resource suspension checks pass. Opaque state remains in memory; no cross-launch history or automatic suspension is claimed.

**11/12 runtime-port checks pass.** Both generations deliver ordered bidirectional nested JSON/Unicode messages, sender metadata and explicit disconnect. Disable-triggered disconnect is observed for MV3 but not MV2; this remains a failed assertion pending content-world/late-message diagnostics. No multi-recipient, worker suspension/wakeup or full Chrome/Firefox port conformance claim follows.

Native-message framing, actual cat/printf/sleep transport cases, deadline/cancellation and exact Chrome host-manifest origin checks pass within the 91 unit tests. The next revision replaces timed idle polling with a wake pipe, adds awaitable child cleanup, and drafts consent/registry/connection management. It is **not wired to production delegates or UI**, and nativeMessaging installation remains blocked. Full original-spec completion remains the goal.

## Prioritized remaining work

| Priority | Requirement | Completion evidence still needed |
|---|---|---|
| P0 | Actual macOS 27 desktop rendering | Genuine rendered pages in real screenshots and a passing retained glyph gate; current free-runner system WebKit failure persists. |
| P0 | Full extension compatibility | [Exact formats/APIs and seven real-package rejections](EXTENSIONS.md). Native Safari/legacy formats, missing engine APIs, production native messaging and broad real-extension semantics remain unsupported or unverified. |
| P1 | Grid/native interaction | Broader resizing, dark/inactive and keyboard/AX inspection; broader windows API semantics. Balanced initial geometry, minimum bounds, history/zoom and command delivery now pass. |
| P1 | Zen parity | Split-group tabs, incremental divider trees, compact toolbar variants, Glance, folders/groups, profiles, import and sync. [Checklist](ZEN_PARITY.md) distinguishes implemented/partial/missing. |
| P1 | Permissions/media/recovery | Physical capture/location behavior, broader subframe consent, fullscreen/media and actual process-crash recovery. Policy-only tests do not establish hardware behavior. |
| P2 | Durability and memory | Full history-stack restoration, automatic suspension preserving media/unsaved work, and automatic pause-on-quit. Normal download history and explicit paused-download recovery across launches are verified. |
| P2 | Visual/accessibility/performance/distribution | Light/dark/inactive/accessibility inspection, representative subprocess-aware benchmarks after rendering works, signing/notarization and installation validation. Only free runners; no user-Mac work. |

## Evidence conventions

Most browser scenarios are in-process integration tests; native keyboard tests and separately supervised quit are labeled. Delegate tests are not JavaScript promise tests. Captures are retrieved and inspected, and screenshot existence alone is never a visual pass. Early diagnostic performance samples include WebKit subprocesses but failed rendering prevents representative browser performance claims. No significant unsupported requirement is waived by a passing compilation or package.


Continuation checkpoint `a1dea358e9c346114ff46b46e411b2d832472300` ([run 36777877403](https://github.com/super-original/serein-browser/actions/runs/36777877403)) builds/tests/packages successfully. All 12 runtime-port checks pass on this run, including MV2 disable-disconnect; the previous intermittent failure remains relevant. The wake-pipe transport and awaitable cleanup compile and pass transport tests. Nine unprimed fullscreen checks and four zoom-event/about:blank checks still fail, as does desktop rendering. Production native-host integration, actual consent and signed MV2/MV3 process fixtures are the next verification target. No completion claim follows.


`40a72fc330f33cd4ab9dd937fbc5b9891aff1adc` ([run 36779482410](https://github.com/super-original/serein-browser/actions/runs/36779482410)) builds, passes 92 unit tests and packages the first production native-host integration. Browser checks are **374/391**: the 13 previous failures plus four native registration/scenario failures. Both unregistered-call denials pass, but consent and process execution were not reached. Capture 42 was retrieved and inspected: the native picker has selected the correct JSON manifest, while Open remains unactivated. The follow-up explicitly verifies that selection and activates the actual panel's Open action before waiting for consent. It also adds background-page/service-worker routes, permission revocation, disable/removal cleanup and a separate quit process holding a live native port. These follow-up results are pending; compilation is not their verification.


## Superseded September 30 checkpoints

## Latest package-format checkpoint

`c0061e9e085134da25f020fc39f99d3aea5b3085`: [run 36787665204](https://github.com/super-original/serein-browser/actions/runs/36787665204) passes **108 unit tests and 409/431 browser checks**, plus **9/9 quit, 12/12 download restart, 12/12 isolated bridge and 8/12 fresh fullscreen**. [App](https://github.com/super-original/serein-browser/actions/runs/36787665204/artifacts/11129749874) · [Evidence](https://github.com/super-original/serein-browser/actions/runs/36787665204/artifacts/11130104629).

Actual folder-to-workspace conversion preserves the live loaded page; creation, nesting, persistence, cancellation, stale-document/membership consent, unpacking and deletion also pass. All 20 MV3 native-host checks pass. The first MV2 picker stays open with its JSON selected; the next revision targets the native Open button directly. Folder AX lookup by displayed name fails, so collapse/context-menu checks remain failed; the correction uses the explicit accessibility identifier. Retrieved/inspected captures 44/46 show the essential, matching 40-point folder/tab pitch and 14-point indentation; 48 shows legible native destructive consent, and 43 shows the registered host without a stale error. The essential tile width still differs from the reference. Web content remains blank and the desktop gate still fails.

The Safari `.appex` fixture compiles, packages and signs, but WebKit rejects its missing `description` before installation consent. No runtime Safari bundle compatibility is claimed from this run. The description is added in the following revision. Its four layout unit tests pass; the remaining runtime outcomes still need execution.

## Folder implementation checkpoint

`de3df8af6e8a8617c33c5cccdab5be6a68c69bc6`: [run 36784268919](https://github.com/super-original/serein-browser/actions/runs/36784268919) passes **101 unit tests, 386/406 browser checks, 9/9 quit, 12/12 download restart, and 12/12 isolated bridge checks**. Fresh fullscreen remains 8/12; desktop rendering still fails. [Download this development app](https://github.com/super-original/serein-browser/actions/runs/36784268919/artifacts/11128744715) · [Evidence](https://github.com/super-original/serein-browser/actions/runs/36784268919/artifacts/11128809511).

Folder creation through native text entry, live-page retention, nesting, session persistence, unpacking, cancellation, and document/membership-bound deletion pass. Captures 44–46 were retrieved and inspected at 1000×677: nesting and 14-point indentation are visible, while the attempted collapsed capture remains expanded. Three collapse checks and four native-host checks fail because their AppleScript input scripts use reserved `control` as a variable and do not compile. The following revision renames that variable and compiles embedded scripts before app launch. These failures are retained, not treated as passing. The other 13 failures match the earlier fullscreen/extension failures below.

The pinned Zen 1.22.2b [reference run 36781892358](https://github.com/super-original/serein-browser/actions/runs/36781892358) supplies four additional inspected folder captures (expanded, collapsed with active child retained, nested, context menu). Native folder icons deliberately use SF Symbols. Live folder providers, custom icons, sharing, conversion to workspaces and drag insertion remain unfinished; native folders do not implement the WebExtensions `tabGroups` API.

The next `5e43906` build passes, but runtime preflight stops before app launch: its initial extractor matched its own pattern string. The revised extractor anchors to actual `osascript` invocations and checks block headers. No browser checks or new screenshots are claimed from that run. Its retrieved evidence passes 9/9 quit, 12/12 download restart and 12/12 isolated bridge checks. The fullscreen probe could not produce results because it depended on the main harness compiling its pointer helper; the next revision compiles its own helper. The rendering step also has no screenshot to assess on this preflight-failed run.

`dfe097fe74315fcf1eb304d3007d773f442d771c` [run 36786312390](https://github.com/super-original/serein-browser/actions/runs/36786312390) passes **104 unit tests, 375/393 browser checks, 9/9 quit, 12/12 download restart, 12/12 isolated bridge and 8/12 fresh fullscreen checks**. The three new folder-conversion state tests pass. The two-window sheet ownership check passes, but actual folder name input fails; its later scenarios are not reached. Native-host input also fails. The inspected 42 capture shows only the desktop after the app exited; the input log says System Events cannot get Serein. The unbounded accessibility-tree scan outlived the app’s input waits. The next revision restores the previously successful native-picker keyboard sequence and bounds AppleScript calls. No runtime folder-conversion success is claimed. [App](https://github.com/super-original/serein-browser/actions/runs/36786312390/artifacts/11129998120) · [Evidence](https://github.com/super-original/serein-browser/actions/runs/36786312390/artifacts/11129703445).

## Latest verified source

`029feec7e9fa9a81fb15f61602387ffc9d7352cc`: [run 36780698616](https://github.com/super-original/serein-browser/actions/runs/36780698616) passes **92 unit tests, 412/425 browser checks, 12/12 independent download-restart checks, 9/9 independent quit checks and 12/12 isolated bridge checks**. Fresh-process fullscreen is **8/12**. Environment: macOS 27.0 26A428, Xcode 27.1 27A9269, Swift 6.4, SDK/minimum 27.0, ARM64.

[Download app](https://github.com/super-original/serein-browser/actions/runs/36780698616/artifacts/11126989926) · [Evidence](https://github.com/super-original/serein-browser/actions/runs/36780698616/artifacts/11128345444). Ad-hoc signed/hardened, not Developer ID signed or notarized. This is a development candidate with known defects.


## Latest verified source

`b3e2899c078124604009415fbc53050e9d30b98e`: [run 36789081403](https://github.com/super-original/serein-browser/actions/runs/36789081403) passes **108 unit tests, 404/421 browser checks, 9/9 quit, 12/12 download restart, 12/12 isolated bridge and 8/12 fresh fullscreen checks**. Environment: macOS 27.0 26A428, Xcode 27.1 27A9269, Swift 6.4, SDK/minimum 27.0, ARM64.

[Download development app](https://github.com/super-original/serein-browser/actions/runs/36789081403/artifacts/11131721219) · [Evidence](https://github.com/super-original/serein-browser/actions/runs/36789081403/artifacts/11131571700). Ad-hoc signed/hardened; not Developer ID signed or notarized.

All **19 folder checks** pass, including actual AX collapse, context-menu capture, creation/nesting/persistence, guarded deletion, unpacking and live folder-to-workspace conversion. All **11 Safari Web Extension bundle checks** pass: native installation/cancellation, unchanged signed manifest, options, MV3 worker messaging, persistent storage/identity after reload, tamper rejection and removal. [Inspected screenshots and pinned Zen comparisons](evidence/2026-09-30/folders-and-safari/README.md) show improved essential width and folder geometry, but still blank WebKit content.

The 17 browser failures comprise the 13 retained fullscreen/extension failures below plus four native-host picker/scenario failures. The inspected picker capture remains in its Go-to-file popup. No native-host lifecycle success is inferred from this run; earlier isolated evidence is retained below.


## Latest verified source

`4140bae6f0b76349ae57a132948d783fa2768ad1`: [run 36791168442](https://github.com/super-original/serein-browser/actions/runs/36791168442) passes **112 unit tests, 457/473 browser checks, 9/9 quit, 12/12 download restart, 12/12 isolated bridge and 8/12 fresh fullscreen checks**. Environment remains macOS 27.0 26A428, Xcode 27.1 27A9269, SDK/minimum 27.0, ARM64.

[Download development app](https://github.com/super-original/serein-browser/actions/runs/36791168442/artifacts/11132128075) · [Evidence](https://github.com/super-original/serein-browser/actions/runs/36791168442/artifacts/11131769594). Ad-hoc signed/hardened; not Developer ID signed or notarized.

All 14 added MV2/MV3 opener/creation checks pass, including final pinned/index/event metadata, opener creation/duplication/update, self rejection and cross-window rejection. All 19 folder and 11 Safari bundle checks continue to pass. Native-host checks pass **43/44**: three picker interactions succeed, while MV3 cancellation remains in Go-to-file. That failure is retained separately; controlled fixture URL review exercises the same production validation and native consent, then all lifecycle checks pass. Actual consent and failed-picker screenshots were retrieved and inspected.

The 16 browser failures comprise 13 retained fullscreen/extension failures, one picker failure, find focus after programmatic close, and initial signed-update options readiness. Native keyboard Escape/page-key delivery and later signed-update restoration still pass. The follow-up waits for body/load completion (the old readiness check waited only for title) and adds a guarded responder restoration request after AppKit window updates.

[Earlier inspected folder/Safari screenshots and pinned Zen comparisons](evidence/2026-09-30/folders-and-safari/README.md) retain the blank WebKit content limitation. No rendering pass or universal extension compatibility is claimed.


### Divider verification failures before f8800b0

`db4aa2e` ([run 36791874134](https://github.com/super-original/serein-browser/actions/runs/36791874134)) fails compilation because the split verification helper collides with a local Boolean name. The following revision renames the helper. `b844659` ([run 36792234519](https://github.com/super-original/serein-browser/actions/runs/36792234519)) passes 114 unit tests and compilation, but the runtime shell exits at its first divider coordinate read because the file lacks a trailing newline. No final browser result is claimed. Independent quit/download/bridge checks pass 9/9, 12/12 and 12/12; fresh fullscreen remains 8/12. The following revision writes a newline and retains input-helper errors as failed checks rather than aborting the supervisor. The macOS 27 typed split resize API compiles; actual pointer-drag/runtime semantics remain pending.


## October 1 divider and crash diagnostics

## Latest verified source

`32b17e3fce2998b30b8807dbd56a5aa95bde904c`: [run 36794473731](https://github.com/super-original/serein-browser/actions/runs/36794473731) passes **114 unit tests, 464/479 browser checks, 44/44 native-host checks, 9/9 quit, 12/12 download restart, 12/12 isolated bridge and 8/12 fresh fullscreen checks**. Independent real-process crash recovery passes **6/7**. Environment remains macOS 27.0 26A428, Xcode 27.1 27A9269, SDK/minimum 27.0, ARM64.

[Download development app](https://github.com/super-original/serein-browser/actions/runs/36794473731/artifacts/11133680561) · [Evidence](https://github.com/super-original/serein-browser/actions/runs/36794473731/artifacts/11133605843). Ad-hoc signed/hardened; not Developer ID signed or notarized.

Both actual divider drags pass, including window resizing and recreated-window persistence (horizontal fraction 0.3503, left vertical fraction 0.6493). The actual resized-grid screenshot was retrieved and inspected: both proportions are visible, while WebKit page bodies remain blank. Find/address focus, all 14 opener/creation, 19 folder, 11 Safari bundle and 44 native-host checks pass.

The 15 browser failures comprise the 13 retained fullscreen/extension failures plus both MV2/MV3 disable-disconnect checks. Document-bound readiness now proves the intended page was tested. After unload, the page probe runs, posting reports no error, and no new echo or disconnect event arrives. This remains a semantic failure, not an accepted compatibility result.

The independent crash supervisor positively attributes WebContent PID 13349 to test app PID 13344 before terminating it. The real delegate fires and invalidates document identity. Both retrieved screenshots show the native “Page stopped” screen and Reload button; the AX lookup failed, so document recovery is **not proven**. Follow-up searches all windows, preserves control diagnostics and permits a unique native Reload action only alongside the crash heading. It never substitutes a programmatic reload for UI input.

[Refreshed pinned Zen references](https://github.com/super-original/serein-browser/actions/runs/36794469990/artifacts/11133112384) contain 23 captures, with all 26 indexed file hashes verified. Light/dark expanded windows and expanded/collapsed folders were inspected. Active/inactive key-window state remains unmatched. [Earlier inspected folder/Safari comparisons](evidence/2026-09-30/folders-and-safari/README.md) retain the blank WebKit limitation.

## Latest diagnostic follow-up

`c2d819b83b9a0d368443bd6560218e93a3a26d83`: [run 36795922611](https://github.com/super-original/serein-browser/actions/runs/36795922611) builds/packages successfully; **114 unit, 463/479 browser, 43/44 native-host, 6/7 crash, 9/9 quit, 12/12 download restart, 12/12 isolated bridge and 8/12 fullscreen** checks pass. The extra browser/native-host failure is MV3 file-picker allow input. [App](https://github.com/super-original/serein-browser/actions/runs/36795922611/artifacts/11133404220) · [evidence](https://github.com/super-original/serein-browser/actions/runs/36795922611/artifacts/11133144692).

Retrieved/inspected recovery screenshot still shows the stopped page. Its actual AX dump proves the outer `page-UUID` identifier was propagated to the crash heading, description **and Reload button**, replacing `page-error-reload`. Follow-up removes that unused container identifier; the action retains its own identifier. This is a production accessibility fix, awaiting native input/recovery verification. Diagnostics now also record native descriptions when SwiftUI button names are absent.

## First actual crash-recovery pass, October 1

## Latest verified source

`d365cfc4ecc9807a420baedff41b1d04af329059`: [run 36796697040](https://github.com/super-original/serein-browser/actions/runs/36796697040) passes **114 unit tests, 467/482 browser checks, all 44 native-host checks, all 7 real-process crash checks, 9 quit, 12 isolated bridge and 8/12 fresh fullscreen checks**. The new download-restart scenario times out before exit; it is not a pass. Environment: image **20260928.0222.1**, macOS 27.0 26A428, Xcode 27.1 27A9269, SDK/minimum 27.0, ARM64.

[Download development app](https://github.com/super-original/serein-browser/actions/runs/36796697040/artifacts/11134068245) · [Evidence](https://github.com/super-original/serein-browser/actions/runs/36796697040/artifacts/11133854312). Ad-hoc signed/hardened; not Developer ID signed or notarized.

Actual attributed WebContent termination, delegate delivery, document invalidation, native AX Reload and same-tab/view recovery all pass. Both screenshots were retrieved and inspected: the native error panel disappears, but recovered website pixels remain blank. The distinct Reload identifier is now visible in the AX dump after removing the inherited container identifier. This proves recovery behavior, not desktop WebKit rendering.

Both native split-divider drags and restored proportions still pass. Three new download checks pass: shutdown dismisses a destination sheet, refuses completion on persistence failure, and succeeds after retry. The separate process test reaches all five preparation checks but calls asynchronous AppKit termination from its own Swift task and never exits; its live download later completes rather than pausing. Follow-up returns from the fixture task and has the independent supervisor send real Command-Q to that child PID. Pause-on-quit is **not yet verified**.

The 15 retained browser failures are nine unprimed ordinary/Glance fullscreen checks, MV2/MV3 zoom events, populated-window about:blank URLs and disable-disconnect delivery. The native-host picker passes all four interactions on this run, but earlier intermittent failures remain under investigation. No full extension or visual parity claim is made.

[Refreshed pinned Zen references](https://github.com/super-original/serein-browser/actions/runs/36794469990/artifacts/11133112384) contain 23 captures; all 26 indexed file hashes were verified. Light/dark expanded windows and expanded/collapsed folders were inspected. Active/inactive window state remains unmatched. [Committed comparisons](evidence/2026-09-30/folders-and-safari/README.md) retain deliberate native material/icon differences and the rendering limitation.
