# Verification and remaining work

**Full original-spec completion remains the goal and is not achieved.** [Draft PR #1](https://github.com/super-original/serein-browser/pull/1) is unmerged. Build success and internal WebKit snapshots are not evidence of correct desktop rendering or full extension compatibility.

## Latest completed source

`89aa2493ec168422cd43f4946adca2277716efcf`: [run 36838423580](https://github.com/super-original/serein-browser/actions/runs/36838423580) passes **147 Swift unit tests, three process-attribution tests and 731/761 browser checks**. All eight new folder-placement checks pass, including actual before/after pointer drags, tree/icon/live-page preservation, atomic rejection and session order. The retrieved original `70-folder-reordered.png` was inspected; the collapsed folder retains its selected page and custom symbol in the expected order. The 30 retained structural failures and desktop-rendering gate still fail.

[Development app](https://github.com/super-original/serein-browser/actions/runs/36838423580/artifacts/11151300151) · [Evidence](https://github.com/super-original/serein-browser/actions/runs/36838423580/artifacts/11150324320). Ad-hoc signed, not notarized; ARM64 macOS 27 minimum.

At `81dafd3`, all 26 folder checks pass, including native icon selection, staged editing, Save, Cancel, reset and persistence. Its picker and sidebar screenshots were inspected. Split focus/restoration repairs remain verified: actual page keys reach the selected WKWebView after arrangement changes, and restored boundaries match saved fractions.

The pinned Zen [reference run 36835530027](https://github.com/super-original/serein-browser/actions/runs/36835530027) passes all 25 captures. Both new three-pane shortcut screenshots and both matching Serein captures were retrieved and inspected; [side-by-side comparison and limitations](evidence/2026-10-01/split-layouts/README.md). Serein's website content remains blank, despite correct native pane geometry. Both uBO origin scenarios pass 13/13 narrow checks; history/privacy restart is 24/24 and download restart 21/21.

The next change joins contiguous regular split tabs in a native sidebar strip, preserving tab/API order and individual controls. Two model tests and three native/keyboard checks await macOS verification. Mixed-category/noncontiguous and persistent multiple groups remain unfinished.

At `b236aa8`, all four download-search checks, six persistent-ID checks, 21 cross-launch download checks, 24 history/privacy checks, 32 favicon checks and seven extension-error checks pass. Both uBO origin modes passed 13/13 then; earlier options timeouts remain intermittent. The filtered-download screenshot and exact native keyboard result count were inspected.

## Measured performance and active follow-up

At `69e6b04`, 24 warm tab switches across four preloaded deterministic pages measured a 17.17 ms median and 24.35 ms nearest-rank p95. The measured interval covers native attachment plus a JavaScript document roundtrip, not visible-frame latency. All three workload/measurement checks pass. This single virtual-runner workload does not establish physical-Mac startup, scrolling or energy performance.

The [inspected chart, CSV and conditions](evidence/2026-10-01/performance-cfb3661/README.md) describe the earlier exact `cfb3661` workload: 121 independent samples, confirmed mixed-workload median RSS 426.69 MiB, peak 1,355.55 MiB and separately reported unresolved RSS up to 69.80 MiB. Warm-idle median RSS was 341.31 MiB, with six confirmed matching processes over 10.173 seconds and 0.0983% interval CPU. The later `1edbfa1` workload (with additional SVG/GPU activity) measured 1.86% over 10.228 seconds. These are not stable physical-Mac performance bounds or directly controlled comparisons. RSS can double-count shared pages; rendering failure and diagnostic overhead limit interpretation.

A production archive-loader optimization removes per-entry input copies, bounds stored-entry writes and shares preflight/extraction bytes while retaining complete validation before destination creation. All four byte-integrity and corrupt-payload tests pass at af67df3. Native checkpoints place the major increase after real uBO Lite initial rule setup, not archive preparation. Default-origin app RSS/physical footprint are 280.66/171.92 MiB after host loading, 909.98/657.33 MiB after initial blocking and 993.30/218.13 MiB after removal/return. This does not establish a leak or isolate a measured archive optimization speedup.

SVG readback now passes with a standard per-canvas hint, with original boundaries and positive/negative checks retained. Production cross-launch history is implemented with an opt-in setting, version/privacy/size safeguards and five-launch verification; 24 production-path checks pass at 69e6b04, including unloaded tabs and disabled-payload removal.

## Retained failures

The 30 structural browser failures comprise nine ordinary/Glance fullscreen checks, two missing `tabs.onZoomChange` events, two empty `about:blank` populated URLs, two port-disable lifecycle checks and 15 network/cookie boundary checks. Revoked background fetch access can survive both propagation and context recreation; MV2 can follow a redirect into a denied host. The conservative Deny Site and Disable Extension command unloads the context and persists denial; it does not establish full per-site enforcement after re-enabling.

The **actual desktop rendering gate fails**, with zero fixture glyph pixels. Plain WKWebView, system Safari and Apple-signed Technology Preview 253 reproduce blank desktop content on the standard free macOS 27 runner. Their retrieved screenshots were inspected. [Independent STP run](https://github.com/super-original/serein-browser/actions/runs/36799509066) · [prepared upstream report](MACOS27_RENDERING_REPORT.md). No second supported free macOS 27 runtime has been identified. The report has not been posted. No private flags, security weakening, lowered deployment target or engine substitution is used.

Fresh baseline and WebGPU-first fullscreen each fail four checks in af67df3. WebGL-first passes four native/DOM entry/exit checks, but its inspected desktop captures remain black/blank; earlier WebGPU passes were intermittent. No production GPU warmup is introduced. [Pinned Gecko reference](https://github.com/super-original/serein-browser/actions/runs/36799509123) renders, removes a disabled extension's DOM listener, and also lacks the expected disconnect marker; neither engine observation proves universal lifecycle behavior.

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

The [extension matrix](EXTENSIONS.md) separates feasible host/API implementation gaps from public platform restrictions. The original seven exact packages request missing capabilities including downloads, history, sessions, tabGroups, idle, identity, offscreen, sidePanel, privacy and blocking webRequest. A narrow isolated native-message namespace experiment passes MV2/MV3, but is not a downloads implementation or a production admission exception. Native Safari formats have no established public host entry point. A custom-engine build/distribution/security-update plan has not been proven feasible within the free-runner limit.

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
