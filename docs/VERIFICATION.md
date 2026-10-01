# Verification and remaining work

**Full original-spec completion remains the goal and is not achieved.** [Draft PR #1](https://github.com/super-original/serein-browser/pull/1) is unmerged. Build success and internal WebKit snapshots are not evidence of correct desktop rendering or full extension compatibility.

## Latest completed source

`d4ebe44a421cd260eaceba42afe14961dbad9517`: [run 36826364165](https://github.com/super-original/serein-browser/actions/runs/36826364165) passes **132 Swift unit tests, three process-attribution tests and 671/710 browser checks**. All four new archive borrowed-buffer/integrity tests pass. Raster favicon formats, CSP/private boundaries, actual effective dark appearance and native own-process memory diagnostics pass. Unmodified uBO Lite passes 13/13 at the default origin and 12/13 at the experimental Firefox origin; the options/background roundtrip remains intermittent.

Favicon automation is 26/31: plain and deliberately active/external SVG images load, but canvas export fails, so all five dependent SVG assertions remain failures. The actual `60-tab-favicons-dark.png` was inspected and is dark, correcting the previous light capture with a dark filename. Website pixels are still blank white. `53-extension-runtime-error.png` shows readable native errors but an older operation error at the bottom; clearing stale operation errors is a pending follow-up.

**Production history persistence passes 19/19 checks across five independent launches**, including actual save/restore, native quit, both navigation directions, document execution, owner-only files and URL-only fallback for disabled preference, mismatched engine and corrupt checksum. Six new core tests verify bounds, identity, privacy and malformed optional state. `57-idle-tab-settings.png` was retrieved and inspected: the new setting is visible, off by default, with readable disclosure in the native scrolling form. Pending follow-up preserves validated history for unloaded background tabs and checks that disabling removes the persisted payload.

Thirty structural browser failures, five SVG failures and four additional intermittent WebGPU fullscreen failures remain. Independent crash, download restart, quit and bridge checks pass; isolated fullscreen is 4/12. The passing WebGL mode still produces blank white/black desktop captures, which were inspected. Native/DOM fullscreen success is not rendered-page evidence.

[Development app](https://github.com/super-original/serein-browser/actions/runs/36826364165/artifacts/11145398316) · [Evidence](https://github.com/super-original/serein-browser/actions/runs/36826364165/artifacts/11145423343). Ad-hoc signed, not notarized; ARM64 macOS 27 minimum.

## Measured performance and active follow-up

The [inspected chart, CSV and conditions](evidence/2026-10-01/performance-cfb3661/README.md) describe the earlier exact `cfb3661` workload: 121 independent samples, confirmed mixed-workload median RSS 426.69 MiB, peak 1,355.55 MiB and separately reported unresolved RSS up to 69.80 MiB. Warm-idle median RSS was 341.31 MiB, with six confirmed matching processes over 10.173 seconds and 0.0983% interval CPU. The later `1edbfa1` workload (with additional SVG/GPU activity) measured 1.86% over 10.228 seconds. These are not stable physical-Mac performance bounds or directly controlled comparisons. RSS can double-count shared pages; rendering failure and diagnostic overhead limit interpretation.

A production archive-loader optimization removes per-entry input copies, bounds stored-entry writes and shares preflight/extraction bytes while retaining complete validation before destination creation. All four byte-integrity and corrupt-payload tests pass at af67df3. Native checkpoints place the major increase after real uBO Lite initial rule setup, not archive preparation. Default-origin app RSS/physical footprint are 280.66/171.92 MiB after host loading, 909.98/657.33 MiB after initial blocking and 993.30/218.13 MiB after removal/return. This does not establish a leak or isolate a measured archive optimization speedup.

SVG readback uses a standard per-canvas hint in the pending follow-up, with original boundaries and positive/negative checks retained. Production cross-launch history is implemented with an opt-in setting, version/privacy/size safeguards and five-launch verification; 19 production-path checks pass at d4ebe44; unloaded-tab and disabled-payload follow-ups remain pending.

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

## Pending production navigation persistence

The next change moves same-build HTTP(S) Back/Forward restoration from a fixture into an opt-in setting. It stores bounded, checksummed state atomically with the normal session, excludes private and edited pages, checks initial and committed history URLs, and falls back to the current URL for invalid or mismatched state. Six unit tests cover legacy sessions, privacy/identity, credentials, corruption, malformed optional data and size limits. The supervised fixture now performs five independent launches through production save/restore, including disabled preference, changed engine and corrupt checksum cases. At d4ebe44 all six new unit tests and all 19 production restart/fallback checks pass. The next iteration additionally unloads the background history tab before saving and verifies that disabled preference removes the payload; those follow-ups remain pending.
