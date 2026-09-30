# Verification and continuation backlog

Full original-spec completion remains the goal and is not achieved. [Draft PR #1](https://github.com/super-original/serein-browser/pull/1) remains unmerged. [Historical checkpoints](VERIFICATION_HISTORY.md) preserve earlier results and failed experiments.

## Folder implementation checkpoint

`de3df8af6e8a8617c33c5cccdab5be6a68c69bc6`: [run 36784268919](https://github.com/super-original/serein-browser/actions/runs/36784268919) passes **101 unit tests, 386/406 browser checks, 9/9 quit, 12/12 download restart, and 12/12 isolated bridge checks**. Fresh fullscreen remains 8/12; desktop rendering still fails. [Download this development app](https://github.com/super-original/serein-browser/actions/runs/36784268919/artifacts/11128744715) · [Evidence](https://github.com/super-original/serein-browser/actions/runs/36784268919/artifacts/11128809511).

Folder creation through native text entry, live-page retention, nesting, session persistence, unpacking, cancellation, and document/membership-bound deletion pass. Captures 44–46 were retrieved and inspected at 1000×677: nesting and 14-point indentation are visible, while the attempted collapsed capture remains expanded. Three collapse checks and four native-host checks fail because their AppleScript input scripts use reserved `control` as a variable and do not compile. The following revision renames that variable and compiles embedded scripts before app launch. These failures are retained, not treated as passing. The other 13 failures match the earlier fullscreen/extension failures below.

The pinned Zen 1.22.2b [reference run 36781892358](https://github.com/super-original/serein-browser/actions/runs/36781892358) supplies four additional inspected folder captures (expanded, collapsed with active child retained, nested, context menu). Native folder icons deliberately use SF Symbols. Live folder providers, custom icons, sharing, conversion to workspaces and drag insertion remain unfinished; native folders do not implement the WebExtensions `tabGroups` API.

The next `5e43906` build passes, but runtime preflight stops before app launch: its initial extractor matched its own pattern string. The revised extractor anchors to actual `osascript` invocations and checks block headers. No browser checks or new screenshots are claimed from that run. Independent scenarios are recorded separately when its job completes.

## Latest verified source

`029feec7e9fa9a81fb15f61602387ffc9d7352cc`: [run 36780698616](https://github.com/super-original/serein-browser/actions/runs/36780698616) passes **92 unit tests, 412/425 browser checks, 12/12 independent download-restart checks, 9/9 independent quit checks and 12/12 isolated bridge checks**. Fresh-process fullscreen is **8/12**. Environment: macOS 27.0 26A428, Xcode 27.1 27A9269, Swift 6.4, SDK/minimum 27.0, ARM64.

[Download app](https://github.com/super-original/serein-browser/actions/runs/36780698616/artifacts/11126989926) · [Evidence](https://github.com/super-original/serein-browser/actions/runs/36780698616/artifacts/11128345444). Ad-hoc signed/hardened, not Developer ID signed or notarized. This is a development candidate with known defects.

## Newly verified native messaging

All **40 production native-host checks** pass across signed MV2/MV3 fixtures: real native consent/cancellation; owner-only persistent registration; one-shot child execution and cleanup; MV2 background-page/MV3 worker execution; ordered persistent-port messages and caller origin; unknown-host denial; permission revoke/regrant; registration revocation; extension disable and removal. The separate quit process opens a real native port, exercises cancel/stale/fresh consent, then verifies successful app exit, saved tabs and absence of its recorded child PID.

[Actual consent and registered-host screenshots](evidence/2026-09-30/native-hosts/README.md) were retrieved and inspected. A stale update-test error appears in the panel; the next revision clears stale errors during registration. Private access, Firefox host identities, automatic host discovery, native-initiated reconnect, broad real-application compatibility and Safari native formats remain unsupported or unverified. Protocol/resource limits remain explicit in [EXTENSIONS.md](EXTENSIONS.md). No universal compatibility follows from these controlled fixtures.

All 12 runtime-port checks pass on this run. MV2 disable-disconnect was intermittent at `3209fee`; multi-recipient differences and worker suspension/wakeup conformance remain unverified.

## Retained failures and graphical evidence

The 13 browser failures are nine unprimed ordinary/Glance fullscreen checks plus missing MV2/MV3 `tabs.onZoomChange` and empty `about:blank` URLs in populated-window results. The separate **actual desktop rendering gate fails**, with zero fixture-content glyph pixels. Plain WKWebView and Apple-signed Safari reproduce IOSurface failures. No second supported free macOS 27 runtime has been identified; no private flags, security weakening, lower deployment target or engine substitution is used. [Prepared upstream report](MACOS27_RENDERING_REPORT.md) has not been posted.

Fresh-process baseline has no GPU process and fails four fullscreen checks. WebGPU-first (adapter null) and WebGL-first each create a GPU process and pass native/DOM entry and Escape. Retrieved/inspected captures remain black in fullscreen and blank in ordinary page bodies. Native/DOM state transitions and internal snapshots do not establish desktop rendering. No production GPU warmup is introduced.

## Other verified behavior

Normal paused downloads resume across app processes with full 8 MiB byte integrity. Private resume data/history stay off disk; owner-only permissions and cleanup pass. Active downloads without saved resume data become interrupted. All 12 ordinary-tab and six extension-resource suspension checks pass, preserving nonempty history/position and zoom while releasing old views. Opaque state is in memory; no cross-launch history or automatic suspension is claimed.

Native window placement/fullscreen/persistence/exit checks pass; the inspected exit capture shows the restored 800×500 frame. Find includes actual Command-F/query/Escape and later page-key delivery. Glance includes Option-click, both Control-Tab directions, Escape, focus, expansion, split/movement, document-bound consent, private isolation, reopen, essential external-link routing and independent popup message-controller ownership. Extension recovery verifies complete history/zoom and exactly one options initialization per restore cycle. Signed updates, command delivery, permission persistence and balanced four-pane grids pass their controlled checks.

[Grid reference comparisons](evidence/2026-09-30/grid/README.md) and [Glance comparisons](evidence/2026-09-30/glance/README.md) retain measured native geometry, intentional material differences and blank WebKit content. Native screenshots do not establish page rendering or full visual parity.

## Prioritized remaining work

| Priority | Requirement | Completion evidence still needed |
|---|---|---|
| P0 | Actual macOS 27 desktop rendering | Rendered page screenshots and retained glyph gate; current free-runner system WebKit failure persists. |
| P0 | Full extension compatibility | [Seven real packages still rejected](EXTENSIONS.md); missing engine/host APIs, Safari native/legacy formats, Firefox native identities, broad semantic and real-extension tests. |
| P1 | Zen parity | Folders/live folders, split-group tabs, incremental divider trees, compact variants, nested previews, profiles, import and sync. Pinned folder reference capture is prepared; no folder implementation is claimed yet. |
| P1 | Permissions/media/recovery | Hardware capture/location, broader subframe consent, rendered fullscreen/media and actual process-crash recovery. |
| P2 | Durability and memory | Cross-launch navigation stacks, safe automatic suspension, pause-on-quit and broader subprocess-aware performance measurement. |
| P2 | Visual/accessibility/distribution | Dark/inactive/AX inspection, remaining focus/menu semantics, installation validation, signing/notarization. |

Most browser checks are in-process integration scenarios. Actual keyboard input and separately supervised quit are labeled. Screenshots are retrieved and inspected. Early performance samples include WebKit subprocesses, but failed rendering prevents representative performance claims. Only standard free runners are used; no user-Mac work.

## Current follow-up

`3787bc1` ([run 36781898641](https://github.com/super-original/serein-browser/actions/runs/36781898641)) built but did not finish its combined browser suite: the native-picker stage stalled before final results. Independent quit/download checks still passed. No final browser pass count is assigned. The synchronous test-side `NSOpenPanel.ok` fallback is removed in favor of an external AX press; incremental native-host stages/results and a timeout screenshot/process sample will localize any recurrence. This is a diagnostic correction, not a claim that the stall's root cause is proven.

The next revision also adds nested pinned folders with nine core cases and actual editor/AX/persistence/deletion scenarios. The pinned Zen folder reference succeeded and all four captures were inspected; browser folder runtime verification is pending. The full original-spec goal and all retained rendering/compatibility failures remain unchanged.
