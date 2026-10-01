# Verification and remaining work

**Full original-spec completion remains the goal and is not achieved.** [Draft PR #1](https://github.com/super-original/serein-browser/pull/1) is unmerged. Build success and internal WebKit snapshots are not evidence of correct desktop rendering or full extension compatibility.

## Latest completed source

`d8cce576ce61d0007d86573be58207a8082c4f80`: [run 36861671906](https://github.com/super-original/serein-browser/actions/runs/36861671906) passes **165 Swift unit tests, three process-attribution tests and 797/828 browser checks**. Fifteen of sixteen split-group runtime checks pass, including all four native tab controls in two horizontal rows. Their Accessibility frames are `(22,227,101,28)`, `(127,227,101,28)`, `(22,267,101,28)`, `(127,267,101,28)` in desktop points. The refreshed screenshot visibly shows both groups. Unloaded URL tabs now show safe filenames before loading. Original screenshots 76/77/79 and the final extension-error screen were retrieved and inspected; website content remains blank.

The remaining new failure is explicit: the tab button's Accessibility show-menu action is unavailable, so the inactive-group context action has not been exercised. The next change attaches the context menu directly to the accessible tab button instead of its surrounding stack. The native test remains unchanged and failed results are retained. Group-wide pinning and mixed-category/noncontiguous presentation remain open.

Real Formatter passes **15/15** again and both uBO origin modes pass their narrow scenarios on this run. Controlled ordering reads `ready/ready`. Earlier real-package, ordering and options timeouts remain intermittent failures; no phase-ordering repair has been introduced. Thirty structural browser failures and the desktop rendering gate remain failed.

[Development app](https://github.com/super-original/serein-browser/actions/runs/36861671906/artifacts/11161944730) · [Evidence](https://github.com/super-original/serein-browser/actions/runs/36861671906/artifacts/11162846024). Ad-hoc signed, not notarized; ARM64 macOS 27 minimum. Evidence ZIP SHA-256: `c8235d990c43ca6230727ff394de3dd411accbcc1923e38476ea96eefd80eaed`.

The pinned Zen comparison at `aa116b5` passes all 28 captures; independent split-group images 26/27/28 were inspected. Original Formatter passes all three Gecko checks with the built-in JSON viewer explicitly disabled and verified. Both Gecko downloads references remain 15/16, including after the shared browser/chrome namespace selection change. The first Chrome references stopped before launch on inventory drift and then the official test build's missing resource seals. [Exact upstream provenance verification and limitations](CHROME_REFERENCE.md) are prepared, with six passing local mutation/missing-file/link/mode tests; no Chrome browser scenario is claimed yet.

The unmodified WebKit build with Metal installed hit its 75-minute budget; [measured resource envelope](evidence/2026-10-01/webkit-build-c366ef2/README.md). [The 180-minute compilation experiment](https://github.com/super-original/serein-browser/actions/runs/36856490466) is still running with unchanged resource guards and without full debug symbols. No framework or engine adoption is claimed.

The 30 retained structural failures and desktop-rendering gate still fail. At `9d8d8c1`, native save-entry repair passes exact name/directory, destination and PNG checks; both save panels and the exported PNG were inspected. Internal snapshot text is visible, while desktop website content stays blank. All three joined split-sidebar checks pass; inspected four-pane labels are heavily truncated at the pinned width.

At `89aa2493`, all eight folder-placement checks pass, including actual before/after pointer drags, tree/icon/live-page preservation, atomic rejection and session order. Its retrieved `70-folder-reordered.png` was inspected; the collapsed folder retains its selected page and custom symbol in the expected order.

At `81dafd3`, all 26 folder checks pass, including native icon selection, staged editing, Save, Cancel, reset and persistence. Its picker and sidebar screenshots were inspected. Split focus/restoration repairs remain verified: actual page keys reach the selected WKWebView after arrangement changes, and restored boundaries match saved fractions.

The pinned Zen [reference run 36835530027](https://github.com/super-original/serein-browser/actions/runs/36835530027) passes all 25 captures. Both new three-pane shortcut screenshots and both matching Serein captures were retrieved and inspected; [side-by-side comparison and limitations](evidence/2026-10-01/split-layouts/README.md). Serein's website content remains blank, despite correct native pane geometry. Both uBO origin scenarios pass 13/13 narrow checks; history/privacy restart is 24/24 and download restart 21/21.

Contiguous regular split tabs now join in a native sidebar strip, preserving tab/API order and individual controls; two model tests and three native/keyboard checks pass. Persistent multiple groups now pass the checks above; mixed-category/noncontiguous group presentation remains unfinished.

At `b236aa8`, all four download-search checks, six persistent-ID checks, 21 cross-launch download checks, 24 history/privacy checks, 32 favicon checks and seven extension-error checks pass. Both uBO origin modes passed 13/13 then; earlier options timeouts remain intermittent. The filtered-download screenshot and exact native keyboard result count were inspected.

Clear History now stages an empty history file before publishing the empty list, so a failed write cannot make the UI falsely show successful deletion. The deliberate destination-write failure and successful retry/relaunch checks both pass at `719f0cf`. This concerns Serein’s saved history list, not cookies, other browser databases, backups or secure filesystem erasure.

## Measured performance and active follow-up

At `dcbcb09`, all ten independent startup launches pass. [Published raw samples, conditions and source-tree verification](evidence/2026-10-01/startup-dcbcb09/README.md): median parent-observed process-spawn readiness is **490.21 ms** for five fresh profiles and **1,363.28 ms** for five one-tab restores. Swift-entry medians are 427.18 ms and 1,333.89 ms respectively. The fresh endpoint is a visible native window; restoration additionally requires attached, loaded content and a JavaScript identity roundtrip. Warm OS/WebKit caches, direct executable launching and 10 ms polling are explicit limitations; no rendered-frame, cold-boot, extension-heavy or physical-Mac performance claim follows.

At `69e6b04`, 24 warm tab switches across four preloaded deterministic pages measured a 17.17 ms median and 24.35 ms nearest-rank p95. The measured interval covers native attachment plus a JavaScript document roundtrip, not visible-frame latency. All three workload/measurement checks pass. This single virtual-runner workload does not establish physical-Mac startup, scrolling or energy performance.

The [inspected chart, CSV and conditions](evidence/2026-10-01/performance-cfb3661/README.md) describe the earlier exact `cfb3661` workload: 121 independent samples, confirmed mixed-workload median RSS 426.69 MiB, peak 1,355.55 MiB and separately reported unresolved RSS up to 69.80 MiB. Warm-idle median RSS was 341.31 MiB, with six confirmed matching processes over 10.173 seconds and 0.0983% interval CPU. The later `1edbfa1` workload (with additional SVG/GPU activity) measured 1.86% over 10.228 seconds. These are not stable physical-Mac performance bounds or directly controlled comparisons. RSS can double-count shared pages; rendering failure and diagnostic overhead limit interpretation.

A production archive-loader optimization removes per-entry input copies, bounds stored-entry writes and shares preflight/extraction bytes while retaining complete validation before destination creation. All four byte-integrity and corrupt-payload tests pass at af67df3. Native checkpoints place the major increase after real uBO Lite initial rule setup, not archive preparation. Default-origin app RSS/physical footprint are 280.66/171.92 MiB after host loading, 909.98/657.33 MiB after initial blocking and 993.30/218.13 MiB after removal/return. This does not establish a leak or isolate a measured archive optimization speedup.

SVG readback now passes with a standard per-canvas hint, with original boundaries and positive/negative checks retained. Production cross-launch history is implemented with an opt-in setting, version/privacy/size safeguards and five-launch verification; 24 production-path checks pass at 69e6b04, including unloaded tabs and disabled-payload removal.

## Retained failures

The 30 structural browser failures comprise nine ordinary/Glance fullscreen checks, two missing `tabs.onZoomChange` events, two empty `about:blank` populated URLs, two port-disable lifecycle checks and 15 network/cookie boundary checks. Revoked background fetch access can survive both propagation and context recreation; MV2 can follow a redirect into a denied host. The conservative Deny Site and Disable Extension command unloads the context and persists denial; it does not establish full per-site enforcement after re-enabling.

The **actual desktop rendering gate fails**, with zero fixture glyph pixels. Plain WKWebView, system Safari and Apple-signed Technology Preview 253 reproduce blank desktop content on the standard free macOS 27 runner. Their retrieved screenshots were inspected. [Independent STP run](https://github.com/super-original/serein-browser/actions/runs/36799509066) · [prepared upstream report](MACOS27_RENDERING_REPORT.md). No second supported free macOS 27 runtime has been identified. The report has not been posted. No private flags, security weakening, lowered deployment target or engine substitution is used.

Fresh baseline and WebGPU-first fullscreen each fail four checks in af67df3. WebGL-first passes four native/DOM entry/exit checks, but its inspected desktop captures remain black/blank; earlier WebGPU passes were intermittent. No production GPU warmup is introduced. [Pinned Gecko reference](https://github.com/super-original/serein-browser/actions/runs/36799509123) renders, removes a disabled extension's DOM listener, and also lacks the expected disconnect marker; neither engine observation proves universal lifecycle behavior.

The original capability ledger now passes core and install/update checks; native access-review automation and inspected sheet now pass. The corrected supervisor passes five macOS tests. The first actual engine attempt reached Xcode but failed because the selected scheme omitted WTF and other dependencies. The complete dependency scheme then compiled for 552 seconds before encountering the missing optional Apple Metal Toolchain; no resource guard fired. The next attempt installs that component on the runner under bounded supervision. [Measurements and exact failure](WEBKIT_FEASIBILITY.md).

## Evidence-backed backlog

| Priority | Work remaining | Acceptance evidence |
|---|---|---|
| 1 | Repair actual macOS 27 WebKit desktop rendering within free-runner constraints | Real visible fixture pixels and inspected light/dark, focus, scrolling, fullscreen and accessibility captures; retained gate passes |
| 1 | Extension permission/lifecycle correctness and missing API families | Passing semantic boundary tests, exact pinned real-package scenarios, explicit format/API matrix; no omitted required permissions |
| 1 | Full Chrome/Firefox/Safari target | Original seven packages still rejected for specified APIs; native Safari App Extensions/legacy formats unsupported. Implement feasible bridges and establish a realistic engine plan for engine gaps; no universal claim from uBO Lite |
| 2 | Zen layout/interaction parity | Pinned 1.22.2b reference comparisons, real pointer/keyboard behavior, remaining compact variants, tab groups, favicon treatment and other checklist gaps |
| 2 | Memory and media safety | Real playback/capture/edit/download races, representative idle/tab/scroll workloads, WebKit subprocess accounting; idle setting remains opt-in |
| 2 | Browser completeness | File/extension back/forward history, profiles/containers, import/sync, wider settings and recovery coverage; see [parity checklist](ZEN_PARITY.md) |
| 3 | Distribution acceptance | Working ARM64 app, actual installation/signing status, reproducible exact-source CI, inspected runtime and complete feature/extension evidence |

The [extension matrix](EXTENSIONS.md) separates feasible host/API implementation gaps from public platform restrictions. The original seven exact packages request missing capabilities including downloads, history, sessions, tabGroups, idle, identity, offscreen, sidePanel, privacy and blocking webRequest. A narrow isolated native-message namespace experiment passes MV2/MV3, but is not a downloads implementation or a production admission exception. Native Safari formats have no established public host entry point. A bounded unmodified public-WebKit build experiment is prepared with explicit time, disk and memory stops; [plan and acceptance limits](WEBKIT_FEASIBILITY.md). No build feasibility, engine adoption or compatibility result is claimed before it runs.

## Verified scope and limits

Selected-tab group dragging, live cross-window moves, folders, split resizing, Glance controls, signed local updates, native-message consent/transport, download resume across process launches, quit consent/failure recovery and actual WebContent-crash recovery have exercised paths. The latest run retains their tests. Full coverage and Zen equivalence do not follow from these scenarios.

The idle policy defaults Off, supports 15/30/60 minutes, excludes visible/private/pinned/essential/extension/file/edited/loading/failed/preview pages and pauses for active downloads. Public media-query timeout preserves the page; identity and policy are rechecked after the reply. In-memory history/position/zoom restoration passes. Unsaved editor detection remains incomplete and some page state can be lost; cross-launch history is opt-in and has the safeguards and limitations described above.

Unmodified uBO Lite Firefox 2026.930.1227 passes 13/13 narrow functional checks in both origin modes at `b5dea7d`, with earlier 12/13 results under both modes. Its initial rule compilation sometimes exceeds the earlier five-second observation window, so the test allows a bounded thirty seconds and records elapsed time. The options exchange has timed out under both modes; the custom origin remains experimental. This does not establish password manager, script manager, downloader or universal extension compatibility.

[25 pinned Zen captures](https://github.com/super-original/serein-browser/actions/runs/36835530027/artifacts/11148957673) provide the reference baseline. [Research](RESEARCH.md), [parity](ZEN_PARITY.md) and [recorded comparisons](evidence/2026-09-30/README.md) distinguish intentional native Liquid Glass treatment from missing behavior. Serein website desktop content remains unverified because the rendering gate fails.

## Performance and distribution

At `7d87985`, a twelve-second, three-tab warm-idle interval reports **395.25 MiB median aggregate RSS and 0.5% interval CPU** across six processes present at both endpoints. The mixed integration workload reports 58 samples, 395.39 MiB median and 1,366.56 MiB peak RSS. WebKit services are attributed by baseline PID difference, RSS may double-count shared pages, and endpoint CPU omits short-lived processes. Broken desktop composition and virtualized CI prevent physical-Mac, energy or representative scrolling claims.

The standard free `xcode-27` runner has used images 20260928.0222.1 and 20260921.0210 (the latter recorded at `9acb833`); the workflow records the exact image on every run. Verified toolchain/runtime: macOS 27.0 26A428, Xcode 27.1 27A9269, SDK/minimum 27.0, ARM64. The app is ad-hoc signed and hardened, not Developer ID signed or notarized. The development download above is not a production-complete browser. No toolchains or build caches are installed on the user's Mac.

[Earlier verification history](VERIFICATION_HISTORY.md) · [October 1 checkpoint history](VERIFICATION_OCTOBER1_HISTORY.md). Historical pending statements remain archived rather than being silently rewritten as passes.


### Performance attribution method

The CI sampler now records exact application PID/start-time/executable identity and reads `launchctl procinfo` responsible PID/path for WebKit processes. This is runner-only diagnostics, not a private API used by the application. `owned-process-samples.jsonl` contains only executable paths, identities, memory/CPU counters, ownership classification and monotonic timing; no process arguments or environment are published. `owned-performance.json` separates confirmed, foreign and unresolved RSS. Unknown ownership is never counted as confirmed browser memory. Existing heuristic measurements remain labeled separately for comparison. Three local parser/attribution/interval tests cover missing ownership, wrong executable/PID and reused PID start times. Idle interval CPU uses only confirmed matching PID/start/executable identities at both endpoints and monotonic elapsed time. Actual runner output is summarized above. Diagnostic overhead, cached attribution (up to ten seconds), shared-page double counting and blank desktop rendering prevent physical memory/energy claims.

## Navigation persistence verification

Opt-in same-build HTTP(S) Back/Forward restoration stores bounded, checksummed state atomically with the normal session. It excludes private/currently edited pages, validates initial and committed URLs, and falls back to the current URL for malformed, disabled or engine-mismatched state. Six core tests first passed at `d4ebe44`; five independent production launches now pass 24 checks, including unloaded background tabs, disabled payload removal, a live private WKWebView excluded from disk, real input-event edit suppression and reload retention. Current evidence is linked above. File/extension history persistence and complete detection of unsaved application state remain gaps.

### 41707ef: native menu association and reference provenance

[Run 36864209415](https://github.com/super-original/serein-browser/actions/runs/36864209415)
builds/tests/packages and completes **796/828 browser checks**. The direct Button context-menu
association still reports `AXShowMenu` unavailable; the original native test fails and
screenshot 79 visibly retains both groups. That image and the final extension-runtime error
screen (53) were retrieved and inspected. The next helper attempts an actual right click at
the uniquely identified tab's AX bounds, logs the unsupported AX action, and still selects
the real native menu item. No model mutation is used to satisfy the menu test.

Formatter's original MAIN-world JSON-global assertion fails again (14/15), while the
controlled end/idle-order scenario passes. Prior all-pass runs do not establish a timing fix.
The original thirty structural failures and desktop blank-content gate remain.
[Development app](https://github.com/super-original/serein-browser/actions/runs/36864209415/artifacts/11163690376)
· [Evidence](https://github.com/super-original/serein-browser/actions/runs/36864209415/artifacts/11163440946),
ZIP SHA-256 `a462ce8ce2be0a52839d56a934588dadcd006ba16dd798e18533b6ae49f7d6ad`.
The separate Chrome reference now verifies upstream file provenance and actual extension
execution; subsequent visible captures and cross-browser download differences are recorded
in [CHROME_REFERENCE.md](CHROME_REFERENCE.md).

### 10e984e: group pinning and actual extension events verified

[Run 36865518399](https://github.com/super-original/serein-browser/actions/runs/36865518399)
passes **169 Swift tests, three process-attribution tests, and 812/844 browser checks**.
All four new group-pin core cases pass. The native pin/unpin/divider/inactive-selection
checks pass, and screenshot 80 visibly shows the joined pair in the pinned section.
Both MV2 and MV3 pass all six real extension checks: both members pin/unpin, each receives
one event per transition, repeated pin is silent, and native selection/divider state remains.
Screenshot 80 and final error screen 53 were retrieved and inspected.

The context-menu AX action still fails. The thirty structural failures persist, and the
controlled end/idle ordering check fails again while the original Formatter passes 15/15.
The desktop rendering gate still fails; no successful website rendering is claimed.
[Development app](https://github.com/super-original/serein-browser/actions/runs/36865518399/artifacts/11164031972)
· [Evidence](https://github.com/super-original/serein-browser/actions/runs/36865518399/artifacts/11164486774),
ZIP SHA-256 `82bdd4b8383e63f087ebd9ec8c441d3645ae64463a6bf092107c6fd306a4a4fc`.
