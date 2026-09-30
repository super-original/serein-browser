# Verification and continuation backlog

Full original-spec completion remains the goal and is not achieved. [Draft PR #1](https://github.com/super-original/serein-browser/pull/1) remains unmerged. [Historical checkpoints](VERIFICATION_HISTORY.md) preserve earlier results and failed experiments.

## Latest verified source

`4140bae6f0b76349ae57a132948d783fa2768ad1`: [run 36791168442](https://github.com/super-original/serein-browser/actions/runs/36791168442) passes **112 unit tests, 457/473 browser checks, 9/9 quit, 12/12 download restart, 12/12 isolated bridge and 8/12 fresh fullscreen checks**. Environment remains macOS 27.0 26A428, Xcode 27.1 27A9269, SDK/minimum 27.0, ARM64.

[Download development app](https://github.com/super-original/serein-browser/actions/runs/36791168442/artifacts/11132128075) · [Evidence](https://github.com/super-original/serein-browser/actions/runs/36791168442/artifacts/11131769594). Ad-hoc signed/hardened; not Developer ID signed or notarized.

All 14 added MV2/MV3 opener/creation checks pass, including final pinned/index/event metadata, opener creation/duplication/update, self rejection and cross-window rejection. All 19 folder and 11 Safari bundle checks continue to pass. Native-host checks pass **43/44**: three picker interactions succeed, while MV3 cancellation remains in Go-to-file. That failure is retained separately; controlled fixture URL review exercises the same production validation and native consent, then all lifecycle checks pass. Actual consent and failed-picker screenshots were retrieved and inspected.

The 16 browser failures comprise 13 retained fullscreen/extension failures, one picker failure, find focus after programmatic close, and initial signed-update options readiness. Native keyboard Escape/page-key delivery and later signed-update restoration still pass. The follow-up waits for body/load completion (the old readiness check waited only for title) and adds a guarded responder restoration request after AppKit window updates.

[Earlier inspected folder/Safari screenshots and pinned Zen comparisons](evidence/2026-09-30/folders-and-safari/README.md) retain the blank WebKit content limitation. No rendering pass or universal extension compatibility is claimed.

## Earlier verified native messaging (`029feec`)

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
| P1 | Zen parity | Live folder providers, custom icons/share/import, arbitrary drag insertion, split-group tabs, incremental divider trees, compact variants, nested previews, profiles and sync. Basic nested folders and conversion now pass controlled checks. |
| P1 | Permissions/media/recovery | Hardware capture/location, broader subframe consent, rendered fullscreen/media and actual process-crash recovery. |
| P2 | Durability and memory | Cross-launch navigation stacks, safe automatic suspension, pause-on-quit and broader subprocess-aware performance measurement. |
| P2 | Visual/accessibility/distribution | Dark/inactive/AX inspection, remaining focus/menu semantics, installation validation, signing/notarization. |

Most browser checks are in-process integration scenarios. Actual keyboard input and separately supervised quit are labeled. Screenshots are retrieved and inspected. Early performance samples include WebKit subprocesses, but failed rendering prevents representative performance claims. Only standard free runners are used; no user-Mac work.

## Current follow-up

`db4aa2e` ([run 36791874134](https://github.com/super-original/serein-browser/actions/runs/36791874134)) fails compilation because the split verification helper collides with a local Boolean name. The following revision renames the helper. The macOS 27 typed split resize API itself compiles; divider persistence and actual pointer-drag runtime checks remain pending.

The first bounded compiler cache saved 113,404,914 compressed bytes (about 108 MiB). Build/test/package took 219 seconds on its initial run and 106 seconds on the next changed-source run (three-second restore). These are single, different-source CI observations, not a controlled performance benchmark. The next cache save was skipped; no allowance was increased.
