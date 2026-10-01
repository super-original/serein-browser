# Verification and continuation backlog

Full original-spec completion remains the goal and is not achieved. [Draft PR #1](https://github.com/super-original/serein-browser/pull/1) remains unmerged. [Historical checkpoints](VERIFICATION_HISTORY.md) preserve earlier results and failed experiments.

## Latest verified source

`eb98a3947c6cd8281d6c3b316554ee669fb22313`: [run 36800835145](https://github.com/super-original/serein-browser/actions/runs/36800835145) passes **114 unit tests, 449/470 recorded browser checks, 40/44 native-host checks, 7/7 real-process crash checks, 17/17 download-restart checks, 9/9 quit, 12/12 isolated bridge and 8/12 fresh fullscreen checks**. Failed folder input skips later folder scenarios, so the denominator still does not represent full fixture coverage. Image 20260928.0222.1, macOS 27.0 26A428, Xcode 27.1 27A9269, SDK/minimum 27.0, ARM64.

[Download development app](https://github.com/super-original/serein-browser/actions/runs/36800835145/artifacts/11135792335) · [Evidence](https://github.com/super-original/serein-browser/actions/runs/36800835145/artifacts/11136261746). Ad-hoc signed/hardened; not Developer ID signed or notarized. Actual website desktop rendering still fails.

The native ownership fix passes rapid window-transfer round trips and reattaches reopened owner tabs with a live, sized view. Essential-link routing and popup edit tracking run again. The retrieved Safari installation capture now shows the actual permission/source-consent sheet rather than a late desktop-only image. Download pause-on-quit, private recovery-data isolation, two-process payload integrity, actual attributed WebContent crash and native Reload remain passing.

All three real Glance AX actions now pass through their native identifiers. Six recoverable failures remain: parent keyboard delivery after closing a preview, four native-host file selections and folder-name submission. The inspected folder failure capture shows the correct typed name still in its editor; Return did not submit. Native file-picker diagnostics show that Go to Folder did not focus its entry. Follow-up explicitly handles folder Return submission, uses foreground-checked public keyboard events, and adds document/responder diagnostics for parent focus. The other 15 fullscreen/zoom/about:blank/port-disconnect failures remain visible.

Further independently feasible work is implemented but awaiting CI: typed live-tab drag between normal windows and into folders, with per-launch/source identity and private-store boundaries; plus cancellation of application termination when session persistence fails. New actual-pointer and storage-failure/retry scenarios preserve failed native input separately from controlled handler checks. The session fix also replies negatively to the original asynchronous termination request if storage failure follows successful unsaved-edit consent, avoiding a stuck termination loop.

[Technology Preview diagnostic](https://github.com/super-original/serein-browser/actions/runs/36799509066) completed on the newer runner image. Both system Safari and Apple-signed Technology Preview 253 reached the fixture title without an obscuring dialog, failed the desktop glyph check, and have **downloaded and visually inspected blank-page screenshots**. [Prepared report](MACOS27_RENDERING_REPORT.md) records this independent newer-WebKit reproduction; it has not been posted upstream.

[Pinned Gecko port reference](https://github.com/super-original/serein-browser/actions/runs/36799509123) also completed and its two rendered screenshots were inspected. Neither generation delivers the content-script disconnect marker on disable, but Gecko removes the retained DOM listener while system WebKit leaves it callable. See [precise lifecycle comparison and MV3 adaptation](EXTENSIONS.md#pinned-gecko-port-disable-comparison-october-1). Neither engine observation proves universal extension compatibility.

[23 refreshed pinned Zen captures](https://github.com/super-original/serein-browser/actions/runs/36794469990/artifacts/11133112384) retain verified file hashes and inspected light/dark/folder states. [Committed comparisons](evidence/2026-09-30/folders-and-safari/README.md) document blank WebKit content and deliberate native material differences.

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
| P2 | Durability and memory | Cross-launch navigation stacks, safe automatic suspension and broader subprocess-aware performance measurement; pause-on-quit now passes. |
| P2 | Visual/accessibility/distribution | Dark/inactive/AX inspection, remaining focus/menu semantics, installation validation, signing/notarization. |

Most browser checks are in-process integration scenarios. Actual keyboard input and separately supervised quit are labeled. Screenshots are retrieved and inspected. Early performance samples include WebKit subprocesses, but failed rendering prevents representative performance claims. Only standard free runners are used; no user-Mac work.

## Current follow-up

Native divider layout, document-bound port setup and native Reload/document recovery have run. Download termination and native Glance control input are the current follow-ups. Process injection uses only a fresh fixture app, requires matching responsibility PID and executable path immediately before each exact-PID signal, and never falls back to a process-name kill. Native error Reload receives an accessibility identifier and actual AX input; screenshots are captured before and after recovery.

The first bounded compiler cache saved 113,404,914 compressed bytes (about 108 MiB). Build/test/package took 219 seconds on its initial run and 106 seconds on the next changed-source run (three-second restore). These are single, different-source CI observations, not a controlled performance benchmark. No allowance was increased.

CI evidence export now indexes original files with SHA-256 and PNG dimensions instead of duplicating their bytes in job logs. Screenshot/diagnostic artifacts remain intact and must still be downloaded and inspected. `script/emit_evidence.py --inline` retains the older explicit diagnostic fallback. A local check indexed 113 files and verified dimensions for 28 PNGs from the failed divider run; this is artifact integrity metadata, not visual approval.

### New independent rendering diagnostic

A separate standard `xcode-27` workflow installs Apple-signed Safari Technology Preview 253 on the ephemeral runner only. [Apple’s release notes](https://developer.apple.com/documentation/safari-technology-preview-release-notes/stp-release-253) and [download page](https://developer.apple.com/safari/technology-preview/) identify the macOS 27 package. Its pinned SHA-256 is `dbfcc270a845b9a7ac74b13b762808ef19a5652eabadc5b7719291754dc01c8e` (136,844,579 bytes, independently streamed and hashed). Package assessment and code-signature checks precede launch; no security setting is disabled. System Safari and the preview load the same local fixture and retain actual desktop screenshots. This is an independent newer-WebKit witness, not Serein’s engine or a substitute for its rendering gate. No result or IOSurface fix is claimed before execution and screenshot inspection.

### Pending download shutdown improvement

The follow-up requests WebKit resume data for active downloads before replying to application termination. It waits at most five seconds, retains the app on timeout or persistence failure, and rechecks document consent after asynchronous work. Private resume data stays memory-only. The two-process verification now starts a second ordinary download without manually pausing it, invokes actual app termination, checks owner-only saved recovery data after exit, then resumes both downloads and verifies each complete 8 MiB payload. These new checks await macOS CI; earlier 12/12 results cover only manually paused downloads.

The first Technology Preview diagnostic stopped before installation because the DMG used a different installer filename. Follow-up discovers exactly one top-level `.pkg` on the hash-verified mounted image before signature assessment. This was a recoverable harness assumption, not a rendering result.

### Follow-up accessibility and runner diagnostics

The `c2d819b` native-host failure screenshot shows the supplied manifest path still inside Go to Folder. Native file selection now polls the exact entered-path field and the native Open/consent controls instead of two fixed-delay Return keys. The helper never presses Return after the path field disappears or accepts native-host consent. The unused Glance container identifier is also removed so Close/Expand/Split keep distinct action identifiers; three actual AX action scenarios are added, with any programmatic fallback kept separate from the input assertion.

Technology Preview [run 36796692831](https://github.com/super-original/serein-browser/actions/runs/36796692831) landed on **image 20260928.0222.1**, still OS 27.0 26A428. The hash-pinned Apple installer and app signature assessment pass; installed build is 22626.1.8.19.2. The retrieved system Safari screenshot shows a Python local-network consent dialog over an unloaded page (`Untitled`), and the preview exposed no window in the initial wait. The 1,411 dark-pixel count is **invalid as content evidence** because it includes the dialog. Follow-up denies only the fixture Python discovery request, waits for browser windows, retains screenshots on automation failure and marks the glyph result unavailable without the `Field Notes` title. No system/preview rendering improvement is established yet.

Compiler-cache accounting switches from anonymous REST to the workflow's read-only Actions token to avoid shared anonymous API limits. The same 512 MiB local / 8 GiB projected bounds remain; failure still skips saving, and no billing/storage allowance changes. Download shutdown now uses a monotonic five-second deadline, and the restart fixture also quits with a live private download to check disk isolation.

The next Technology Preview run, [36797655651](https://github.com/super-original/serein-browser/actions/runs/36797655651), reaches both fixture titles but its two retrieved screenshots still show Python consent. Both nominal glyph passes are rejected after inspection. Follow-up reuses the previously verified native Don't Allow action and requires UserNotificationCenter to have no remaining window before a glyph result is considered usable. A fixture title alone did not exclude an overlaid native dialog.

Inspection of the late `c1e2498` Safari-install capture shows only the desktop after Serein exited, confirming that capture delivery was stale rather than a valid installation screenshot. Native input is now supervised with a wall-clock child-process timeout (4 seconds for Glance, 6.5 otherwise). The file picker queries only its focused path field; enumerating every file-row accessibility object made the earlier helper outlive the fixture. These changes preserve failed-input assertions and prevent late keystrokes/captures from being counted as current evidence.


### Session persistence failure during quit

`saveNow` now reports success. Both immediate and asynchronous quit paths retain the app and surface the save error when the session cannot be committed. Native messaging accepts new connections again after cancellation. A controlled test obstructs only its isolated `session.json` destination, confirms the app and edited tabs survive the failed quit, repairs the obstruction, requires fresh consent and checks the final saved session and real process exit. Ordinary and active-native-host variants await the next exact-head run; no new pass is claimed yet.
