# Verification and remaining work

**Full original-spec completion remains the goal and is not achieved.** [Draft PR #1](https://github.com/super-original/serein-browser/pull/1) is unmerged. Build success and internal WebKit snapshots are not evidence of correct desktop rendering or full extension compatibility.

## Latest completed source

`cfb3661928773c93f3fd18a73b7bf82fd9468430`: [run 36821911055](https://github.com/super-original/serein-browser/actions/runs/36821911055) passes **122 Swift unit tests, three process-attribution tests and 667/697 browser checks**. All **19 favicon checks pass**, including original fetch capture, meta/removed-meta/header CSP, private-cookie boundaries, bounds, stale navigation, suspended-view release and native tab categories. The exact-run native favicon screenshot was downloaded and inspected; icons are visible while desktop website content remains blank. The earlier isolated-world CSP defect is fixed.

The 30 retained browser failures remain. Independent crash, download restart, quit and bridge checks pass; fresh fullscreen stays 8/12. Main-process WebGPU fullscreen checks pass again after their prior failure, so those transitions remain intermittent. Public opaque history state is a bounded Data value (1,242 bytes in the fixture), but the first cross-process experiment failed its initial three-entry-history preparation assertion and stopped before relaunch. No cross-launch restoration pass is claimed. A stronger native readiness check and detailed back/current/forward diagnostics are pending.

uBO Lite is **13/13 at the default origin and 12/13 at the experimental Firefox origin**. The latter's original options request replied 162 ms into the additional observation period after its ten-second timeout; the options UI was still loading at that instant. The prior run's late reply took 5.621 seconds and the UI had finished loading. These occurrences establish delayed replies, not reliable readiness. The original timeout remains failed.

Process ownership evidence includes 121 independent samples. Confirmed RSS median over the full mixed workload is **426.69 MiB**, with up to **69.80 MiB unresolved RSS** reported separately. Six idle samples span **10.173 seconds**; interval CPU is **0.0983%** across six confirmed matching process identities. This is one short virtualized run with blank desktop rendering and diagnostic overhead; RSS can double-count shared pages and does not establish physical memory, energy efficiency or total browser usage when attribution is unresolved.

[Development app](https://github.com/super-original/serein-browser/actions/runs/36821911055/artifacts/11144122410) · [Evidence](https://github.com/super-original/serein-browser/actions/runs/36821911055/artifacts/11144097804). Ad-hoc signed, not notarized; ARM64 macOS 27 minimum.

## Active follow-up

Original JPEG/GIF/TIFF/WebP/ICO fixtures, bounded SVG-to-PNG icon rendering, SVG script/external-resource and CSP boundaries, aspect-ratio preservation and a dark native sidebar capture are pending exact-head verification. SVG is used only as an image; it is never inserted as a document. Cross-origin/CDN icons, dynamic changes and persisted caching remain gaps.

The history fixture now waits on native WKWebView loading and back/current/forward state together, records the actual lists, and can collect second-launch diagnostics even when preparation assertions fail. All semantic failures remain in its final gate. Production cross-launch navigation history remains unfinished.

## Retained failures

The 30 structural browser failures comprise nine ordinary/Glance fullscreen checks, two missing `tabs.onZoomChange` events, two empty `about:blank` populated URLs, two port-disable lifecycle checks and 15 network/cookie boundary checks. Revoked background fetch access can survive both propagation and context recreation; MV2 can follow a redirect into a denied host. The conservative Deny Site and Disable Extension command unloads the context and persists denial; it does not establish full per-site enforcement after re-enabling.

The **actual desktop rendering gate fails**, with zero fixture glyph pixels. Plain WKWebView, system Safari and Apple-signed Technology Preview 253 reproduce blank desktop content on the standard free macOS 27 runner. Their retrieved screenshots were inspected. [Independent STP run](https://github.com/super-original/serein-browser/actions/runs/36799509066) · [prepared upstream report](MACOS27_RENDERING_REPORT.md). No second supported free macOS 27 runtime has been identified. The report has not been posted. No private flags, security weakening, lowered deployment target or engine substitution is used.

Fresh baseline fullscreen fails four checks without a GPU process. WebGPU-first and WebGL-first processes each pass four native/DOM entry/exit checks, but their inspected desktop captures remain black/blank. No production GPU warmup is introduced. [Pinned Gecko reference](https://github.com/super-original/serein-browser/actions/runs/36799509123) renders, removes a disabled extension's DOM listener, and also lacks the expected disconnect marker; neither engine observation proves universal lifecycle behavior.

## Evidence-backed backlog

| Priority | Work remaining | Acceptance evidence |
|---|---|---|
| 1 | Repair actual macOS 27 WebKit desktop rendering within free-runner constraints | Real visible fixture pixels and inspected light/dark, focus, scrolling, fullscreen and accessibility captures; retained gate passes |
| 1 | Extension permission/lifecycle correctness and missing API families | Passing semantic boundary tests, exact pinned real-package scenarios, explicit format/API matrix; no omitted required permissions |
| 1 | Full Chrome/Firefox/Safari target | Original seven packages still rejected for specified APIs; native Safari App Extensions/legacy formats unsupported. Implement feasible bridges and establish a realistic engine plan for engine gaps; no universal claim from uBO Lite |
| 2 | Zen layout/interaction parity | Pinned 1.22.2b reference comparisons, real pointer/keyboard behavior, remaining compact variants, tab groups, favicon treatment and other checklist gaps |
| 2 | Memory and media safety | Real playback/capture/edit/download races, representative idle/tab/scroll workloads, WebKit subprocess accounting; idle setting remains opt-in |
| 2 | Browser completeness | Cross-launch back/forward history, profiles/containers, import/sync, wider settings and recovery coverage; see [parity checklist](ZEN_PARITY.md) |
| 3 | Distribution acceptance | Working ARM64 app, actual installation/signing status, reproducible exact-source CI, inspected runtime and complete feature/extension evidence |

The [extension matrix](EXTENSIONS.md) separates feasible host/API implementation gaps from public platform restrictions. The original seven exact packages request missing capabilities including downloads, history, sessions, tabGroups, idle, identity, offscreen, sidePanel, privacy and blocking webRequest. A narrow isolated native-message namespace experiment passes MV2/MV3, but is not a downloads implementation or a production admission exception. Native Safari formats have no established public host entry point. A custom-engine build/distribution/security-update plan has not been proven feasible within the free-runner limit.

## Verified scope and limits

Selected-tab group dragging, live cross-window moves, folders, split resizing, Glance controls, signed local updates, native-message consent/transport, download resume across process launches, quit consent/failure recovery and actual WebContent-crash recovery have exercised paths. The latest run retains their tests. Full coverage and Zen equivalence do not follow from these scenarios.

The idle policy defaults Off, supports 15/30/60 minutes, excludes visible/private/pinned/essential/extension/file/edited/loading/failed/preview pages and pauses for active downloads. Public media-query timeout preserves the page; identity and policy are rechecked after the reply. In-memory history/position/zoom restoration passes. Unsaved editor detection remains incomplete and some page state can be lost; cross-launch history is not implemented.

Unmodified uBO Lite Firefox 2026.930.1227 has passed 13/13 narrow functional checks in both origin modes on earlier runs, with 12/13 results under both modes on the latest run. Its initial rule compilation sometimes exceeds the earlier five-second observation window, so the test allows a bounded thirty seconds and records elapsed time. The options exchange has timed out under both modes; the custom origin remains experimental. This does not establish password manager, script manager, downloader or universal extension compatibility.

[23 pinned Zen captures](https://github.com/super-original/serein-browser/actions/runs/36794469990/artifacts/11133112384) provide the reference baseline. [Research](RESEARCH.md), [parity](ZEN_PARITY.md) and [recorded comparisons](evidence/2026-09-30/README.md) distinguish intentional native Liquid Glass treatment from missing behavior. Serein website desktop content remains unverified because the rendering gate fails.

## Performance and distribution

At `7d87985`, a twelve-second, three-tab warm-idle interval reports **395.25 MiB median aggregate RSS and 0.5% interval CPU** across six processes present at both endpoints. The mixed integration workload reports 58 samples, 395.39 MiB median and 1,366.56 MiB peak RSS. WebKit services are attributed by baseline PID difference, RSS may double-count shared pages, and endpoint CPU omits short-lived processes. Broken desktop composition and virtualized CI prevent physical-Mac, energy or representative scrolling claims.

The standard free `xcode-27` image is 20260928.0222.1: macOS 27.0 26A428, Xcode 27.1 27A9269, SDK/minimum 27.0, ARM64. The app is ad-hoc signed and hardened, not Developer ID signed or notarized. The development download above is not a production-complete browser. No toolchains or build caches are installed on the user's Mac.

[Earlier verification history](VERIFICATION_HISTORY.md) · [October 1 checkpoint history](VERIFICATION_OCTOBER1_HISTORY.md). Historical pending statements remain archived rather than being silently rewritten as passes.


### Performance attribution method

The CI sampler now records exact application PID/start-time/executable identity and reads `launchctl procinfo` responsible PID/path for WebKit processes. This is runner-only diagnostics, not a private API used by the application. `owned-process-samples.jsonl` contains only executable paths, identities, memory/CPU counters, ownership classification and monotonic timing; no process arguments or environment are published. `owned-performance.json` separates confirmed, foreign and unresolved RSS. Unknown ownership is never counted as confirmed browser memory. Existing heuristic measurements remain labeled separately for comparison. Three local parser/attribution/interval tests cover missing ownership, wrong executable/PID and reused PID start times. Idle interval CPU uses only confirmed matching PID/start/executable identities at both endpoints and monotonic elapsed time. Actual runner output is summarized above. Diagnostic overhead, cached attribution (up to ten seconds), shared-page double counting and blank desktop rendering prevent physical memory/energy claims.
