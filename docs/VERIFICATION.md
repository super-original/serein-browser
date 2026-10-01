# Verification and continuation backlog

Full original-spec completion remains the goal and is not achieved. [Draft PR #1](https://github.com/super-original/serein-browser/pull/1) remains unmerged. [Historical checkpoints](VERIFICATION_HISTORY.md) preserve earlier results and failed experiments.

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

Native divider layout and document-bound port setup have run. Native Reload input and real document recovery require another run. Process injection uses only a fresh fixture app, requires matching responsibility PID and executable path immediately before each exact-PID signal, and never falls back to a process-name kill. Native error Reload receives an accessibility identifier and actual AX input; screenshots are captured before and after recovery.

The first bounded compiler cache saved 113,404,914 compressed bytes (about 108 MiB). Build/test/package took 219 seconds on its initial run and 106 seconds on the next changed-source run (three-second restore). These are single, different-source CI observations, not a controlled performance benchmark. No allowance was increased.

CI evidence export now indexes original files with SHA-256 and PNG dimensions instead of duplicating their bytes in job logs. Screenshot/diagnostic artifacts remain intact and must still be downloaded and inspected. `script/emit_evidence.py --inline` retains the older explicit diagnostic fallback. A local check indexed 113 files and verified dimensions for 28 PNGs from the failed divider run; this is artifact integrity metadata, not visual approval.

### New independent rendering diagnostic

A separate standard `xcode-27` workflow installs Apple-signed Safari Technology Preview 253 on the ephemeral runner only. [Apple’s release notes](https://developer.apple.com/documentation/safari-technology-preview-release-notes/stp-release-253) and [download page](https://developer.apple.com/safari/technology-preview/) identify the macOS 27 package. Its pinned SHA-256 is `dbfcc270a845b9a7ac74b13b762808ef19a5652eabadc5b7719291754dc01c8e` (136,844,579 bytes, independently streamed and hashed). Package assessment and code-signature checks precede launch; no security setting is disabled. System Safari and the preview load the same local fixture and retain actual desktop screenshots. This is an independent newer-WebKit witness, not Serein’s engine or a substitute for its rendering gate. No result or IOSurface fix is claimed before execution and screenshot inspection.

### Pending download shutdown improvement

The follow-up requests WebKit resume data for active downloads before replying to application termination. It waits at most five seconds, retains the app on timeout or persistence failure, and rechecks document consent after asynchronous work. Private resume data stays memory-only. The two-process verification now starts a second ordinary download without manually pausing it, invokes actual app termination, checks owner-only saved recovery data after exit, then resumes both downloads and verifies each complete 8 MiB payload. These new checks await macOS CI; earlier 12/12 results cover only manually paused downloads.

The first Technology Preview diagnostic stopped before installation because the DMG used a different installer filename. Follow-up discovers exactly one top-level `.pkg` on the hash-verified mounted image before signature assessment. This was a recoverable harness assumption, not a rendering result.
