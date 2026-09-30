# Verification and continuation backlog

Full original-spec completion remains the goal and is not achieved. [Draft PR #1](https://github.com/super-original/serein-browser/pull/1) remains unmerged. [Historical checkpoints](VERIFICATION_HISTORY.md) preserve earlier results and failed experiments.

## Latest verified source

`b3e2899c078124604009415fbc53050e9d30b98e`: [run 36789081403](https://github.com/super-original/serein-browser/actions/runs/36789081403) passes **108 unit tests, 404/421 browser checks, 9/9 quit, 12/12 download restart, 12/12 isolated bridge and 8/12 fresh fullscreen checks**. Environment: macOS 27.0 26A428, Xcode 27.1 27A9269, Swift 6.4, SDK/minimum 27.0, ARM64.

[Download development app](https://github.com/super-original/serein-browser/actions/runs/36789081403/artifacts/11131721219) · [Evidence](https://github.com/super-original/serein-browser/actions/runs/36789081403/artifacts/11131571700). Ad-hoc signed/hardened; not Developer ID signed or notarized.

All **19 folder checks** pass, including actual AX collapse, context-menu capture, creation/nesting/persistence, guarded deletion, unpacking and live folder-to-workspace conversion. All **11 Safari Web Extension bundle checks** pass: native installation/cancellation, unchanged signed manifest, options, MV3 worker messaging, persistent storage/identity after reload, tamper rejection and removal. [Inspected screenshots and pinned Zen comparisons](evidence/2026-09-30/folders-and-safari/README.md) show improved essential width and folder geometry, but still blank WebKit content.

The 17 browser failures comprise the 13 retained fullscreen/extension failures below plus four native-host picker/scenario failures. The inspected picker capture remains in its Go-to-file popup. No native-host lifecycle success is inferred from this run; earlier isolated evidence is retained below.

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

Tab creation/opener metadata and event payload tests are pending exact-head CI. Native-host picker failures now remain separate failed checks while the same production validation and native consent can run independently with a controlled fixture URL. This does not turn failed picker automation into a pass. File reads are bounded to 1 MiB plus one rejection byte. Additional path-entry settling time addresses the observed unfinished Go-to-file dialog.

The first bounded compiler cache saved 113,404,914 compressed bytes (about 108 MiB). No measured build-time improvement is claimed yet. Package resources/signatures and every test are still rebuilt or executed.
