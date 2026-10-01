# Verification and remaining work

**Full original-spec completion remains the goal and is not achieved.** [Draft PR #1](https://github.com/super-original/serein-browser/pull/1) is unmerged. Build success and internal WebKit snapshots are not evidence of correct desktop rendering or full extension compatibility.

## Latest completed source

`e8cf458fe01fcd277cf8cddd222879dc43b8dae5`: [run 36817944745](https://github.com/super-original/serein-browser/actions/runs/36817944745) passes **122 unit tests and 647/678 browser checks**. All five new download-metadata checks pass: original/final redirected URLs, MIME type, exact response bytes/completion time, restored history, paused counts and full resumed counts. The native download panel screenshot `19-downloads-paused.png` was retrieved and inspected; received/expected amounts are legible. This is model groundwork, not an extension downloads API.

All **14 page-screenshot, 20 idle-policy and six real-audio checks** remain passing. The previous run's native save sheet and exported PNG were inspected separately: the PNG contains the page, while desktop WebKit content is blank. Native input starts audio, it continues after tab switching and idle unloading preserves playing/paused pages. Physical output/capture and broad editor-state preservation remain unverified.

uBO Lite is **12/13 in both origin modes** on this run. Options messaging times out while its own options UI stays loading; permissions, local/session storage, scripting enumeration and DNR queries respond in approximately 10–14 ms. Managed storage is absent. The package checks for that absence, so it is not an established cause. Earlier 13/13 runs do not establish reliable compatibility. There are now the same 30 structural failures plus this recurring real-package timeout. The controlled origin probe stays 8/8; independent native-host 44/44, crash 7/7, download restart 17/17, quit 13/13, bridge 12/12 and fresh fullscreen 8/12 results remain unchanged.

[Development app](https://github.com/super-original/serein-browser/actions/runs/36817944745/artifacts/11142701802) · [Evidence](https://github.com/super-original/serein-browser/actions/runs/36817944745/artifacts/11142915228). Ad-hoc signed, not notarized; ARM64 macOS 27 minimum.

## Active follow-up

Pending native favicons use a bounded same-origin request in the page's isolated WebKit world and data store, then ImageIO thumbnail decoding. No native cookie copying or persistent image cache is added. Controlled scenarios exercise original PNG pixels, page-world overrides, private cookies, CSP, cross-origin/file/redirect refusal, encoded/dimension limits, stale navigation, unloaded tabs and all sidebar tab categories. Runtime and screenshot inspection are still required. SVG, cross-origin and dynamic icon updates remain gaps.

The real-extension timeout follow-up retains the original response promise and observes a further bounded twenty seconds after immediate read-only diagnostics. A late response never replaces the original timeout failure. This distinguishes delayed initialization from a request that remains unanswered without patching the package or granting additional permissions.

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
