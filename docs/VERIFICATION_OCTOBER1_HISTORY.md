# Historical October 1 continuation checkpoints

Archived before page-screenshot verification. Pending statements and earlier failures below are historical; consult [current verification](VERIFICATION.md) for the latest state.

# Verification and continuation backlog

Full original-spec completion remains the goal and is not achieved. [Draft PR #1](https://github.com/super-original/serein-browser/pull/1) remains unmerged. [Historical checkpoints](VERIFICATION_HISTORY.md) preserve earlier results and failed experiments.

## Latest verified source

`f8e857dcf12f052215117362434f7039352999e9`: [run 36814920146](https://github.com/super-original/serein-browser/actions/runs/36814920146) passes **120 unit tests and 622/652 browser checks**. All **19 idle-suspension checks** pass, including public no-media unloading, old-view release, history/zoom restoration, exclusions and controlled asynchronous races. Both sleeping-tab assertions pass after isolating the sender probe. Actual audio playback protection is the next scenario; controlled media replies do not prove it. The retrieved `57-idle-tab-settings.png` was inspected: the Off selector and state-loss/exclusion explanation are legible, while desktop web content remains blank.

uBO Lite passes **13/13 in both origin modes** on this run; the earlier intermittent custom options timeout remains recorded. Independent native-host 44/44, crash 7/7, download restart 17/17, quit 13/13, bridge 12/12 and fresh fullscreen 8/12 results are unchanged. The same 30 main failures and rendering gate remain. [Development app](https://github.com/super-original/serein-browser/actions/runs/36814920146/artifacts/11140309560) · [Evidence](https://github.com/super-original/serein-browser/actions/runs/36814920146/artifacts/11140214677). Ad-hoc signed, not notarized; ARM64 macOS 27 minimum.

### Previous sender checkpoint

`47c6c1ab8eebc3c1a3e072bf77ed12de26c4a3c9`: [run 36813903855](https://github.com/super-original/serein-browser/actions/runs/36813903855) passes **120 unit tests and 601/633 browser checks**. All four default-origin sender checks and all eight controlled custom-origin checks pass, with correct sender URL/origin metadata. uBO Lite is **13/13 in both modes** on this run; default initial/restored blocking took 6.67/4.75 seconds, custom 6.75/5.55 seconds. The earlier custom options timeout is therefore intermittent, not an established origin mismatch or resolved compatibility defect. Its retrieved custom-origin desktop screenshot was inspected and remains blank.

The two new failures are `tabs-query-keeps-unloaded-tab-asleep` in both generations. The sender probe closed its selected tab beside the deliberately sleeping fixture tab; ordinary close selection then loaded that neighbor before the tabs-query assertion. The next revision moves the probe into a separate window and keeps both lazy-loading assertions. Until rerun, this is a diagnosed fixture interference, not a passing test. [App](https://github.com/super-original/serein-browser/actions/runs/36813903855/artifacts/11141090704) · [Evidence](https://github.com/super-original/serein-browser/actions/runs/36813903855/artifacts/11140164995).

### Previous production checkpoint

`e2339f26e4ca92171ba4005cd52f52beeade4802`: [run 36812749134](https://github.com/super-original/serein-browser/actions/runs/36812749134) passes **120 unit tests and 599/629 browser checks**. All **10 selected-tab group checks** pass, including a real pointer drag, both live documents, selection/order, stale/duplicate refusal and private boundaries. All **21 DNR controls**, **5 runtime-error/action-boundary checks** and both declared-action checks pass. Retrieved and inspected `56-selected-tab-drop.png` shows the selected pair in its folder; `53-extension-runtime-error.png` shows the background-only action disabled and the operation error dismissible. Web content remains blank on the desktop.

**Unmodified uBO Lite Firefox 2026.930.1227 now passes 13/13 checks with the production default WebKit origin.** Initial shipped-rule blocking took 9.63 seconds, and re-enabled blocking took 1.61 seconds; the original options/background round trip succeeds. The earlier five-second window was insufficient for this run. Implicit resource types also block correctly in the controlled fixture. The experimental Firefox origin passes **12/13**: initial/re-enabled blocking takes 7.89/7.84 seconds, but its options message times out. It stays experimental; the next controlled sender-origin check investigates that boundary. These are narrow real-package scenarios, not full extension compatibility.

[Latest development app](https://github.com/super-original/serein-browser/actions/runs/36812749134/artifacts/11140178557) · [Latest evidence](https://github.com/super-original/serein-browser/actions/runs/36812749134/artifacts/11140243382). Independent results remain 44/44 native-host, 7/7 crash, 17/17 download, 13/13 quit, 12/12 bridge and 8/12 fullscreen. The 30 main browser failures and actual desktop rendering gate remain; no completion claim is made.

### Prior control checkpoint

`ac5fdcbbc6703735ab48cc6a90f1146ef4163c36`: [run 36811732723](https://github.com/super-original/serein-browser/actions/runs/36811732723) passes **120 unit tests and 582/615 browser checks**, with unchanged 44/44 native-host, 7/7 crash, 17/17 download, 13/13 quit, 12/12 bridge and 8/12 fresh fullscreen outcomes. **All 20 declarative-rule control checks pass**, including actual static/dynamic/session script blocking, positive controls, private exclusion, removal and dynamic persistence across context recreation. This narrows the real uBO Lite failure to differences beyond basic rule hosting; it remains 10/13 in both origin modes. The next diagnostic adds implicit resource types and gives the unmodified real package a bounded 30-second rule-startup window (previously approximately five seconds), retaining execution-based acceptance.

[Latest development app](https://github.com/super-original/serein-browser/actions/runs/36811732723/artifacts/11140076616) · [Latest evidence](https://github.com/super-original/serein-browser/actions/runs/36811732723/artifacts/11139772785). Retrieved and inspected `53-extension-runtime-error.png` confirms the new Dismiss control and legible row errors; its misleading background-only action is addressed in the pending follow-up. Desktop rendering still fails. The following checkpoint describes the prior production fixes:

`7d87985a4e20e9905520b4fe8479866312bb9f63`: [run 36810498761](https://github.com/super-original/serein-browser/actions/runs/36810498761) passes **120 unit tests, 562/595 recorded browser checks, 44/44 native-host, 7/7 real-process crash recovery, 17/17 download restart, 13/13 quit, 12/12 isolated bridge and 8/12 fresh fullscreen checks**. Image 20260928.0222.1, macOS 27.0 26A428, Xcode 27.1 27A9269, SDK/minimum 27.0, ARM64. The workflow fails its retained runtime/rendering gates; this is not completion.

[Download development app](https://github.com/super-original/serein-browser/actions/runs/36810498761/artifacts/11139204718) · [Evidence](https://github.com/super-original/serein-browser/actions/runs/36810498761/artifacts/11139359225). Ad-hoc signed/hardened; not Developer ID signed or notarized. Actual website desktop rendering still fails.

The main suite now completes again. All **54 signed-update checks** pass after unavailable extension pages became tab-local errors and the harness identified the exact update sheet. Retrieved and inspected `55-disabled-extension-page.png` shows the native recovery message and Reload button. All **19 drag checks**, including real upper/lower-half pointer insertion with retained live content/history, pass. All 8 requesting-frame consent, 12 extension-consent lifecycle, 19 folder and 44 native-host checks remain passing. These native-sheet checks do not establish physical media/TCC or JavaScript optional-permission event semantics.

All **4 asynchronous extension-error checks** pass. Retrieved and inspected `53-extension-runtime-error.png` shows the missing module and background-load failure in the correct management row. It also exposes an unrelated retained update error; the next revision adds explicit dismissal. Disabled contexts clear their row errors.

Network checks are **16/24 MV2 and 17/24 MV3**. Native granted/denied policy reflects host revocation, but readable fetch survives both bounded propagation and public disable/re-enable with persisted denial. MV2 also reads through a denied redirect target. Cookies emit two malformed change payloads and no valid change events in each generation; host denial hides values with null instead of rejection. The new **Deny Site and Disable Extension** action passes private-window refusal, live-context unload and persisted disabled/denied policy in both generations. It is a visible conservative restriction, not full per-site enforcement; re-enabling may restore denied access.

The eighth pinned real package, **uBO Lite Firefox 2026.930.1227**, passes **10/13** checks with both default and registered Firefox resource origins. Public background loading succeeds, context errors are empty and enabled rulesets include EasyList; its shipped blocking rule, original options/background round trip and re-enabled blocking still fail. It is **not functionally compatible**. The original seven remain rejected, with missing host/API work distinguished from native Safari format restrictions in [EXTENSIONS.md](EXTENSIONS.md). A background-free original static/dynamic/session rule fixture is pending to isolate engine rules from package startup.

Both isolated custom-origin processes now exit normally after the documented public scheme registration. The controlled probe passes **6/6**; real-package checks remain **10/13**. Retrieved and inspected `extension-origins/controlled/resource-page.png` shows native chrome and a blank desktop page despite successful DOM checks. Production XPI installation still uses default origins; these narrow checks do not establish Firefox equivalence or desktop rendering.

The 15 combined ordinary/Glance fullscreen, absent zoom-event, empty about:blank URL and unload-port failures remain. Failed-session-save quit/retry, external Command-Q download pause/resume, private recovery isolation and actual attributed WebContent crash recovery remain passing.

[Technology Preview diagnostic](https://github.com/super-original/serein-browser/actions/runs/36799509066) completed on the newer runner image. Both system Safari and Apple-signed Technology Preview 253 reached the fixture title without an obscuring dialog, failed the desktop glyph check, and have **downloaded and visually inspected blank-page screenshots**. [Prepared report](MACOS27_RENDERING_REPORT.md) records this independent newer-WebKit reproduction; it has not been posted upstream.

[Pinned Gecko port reference](https://github.com/super-original/serein-browser/actions/runs/36799509123) also completed and its two rendered screenshots were inspected. Neither generation delivers the content-script disconnect marker on disable, but Gecko removes the retained DOM listener while system WebKit leaves it callable. See [precise lifecycle comparison and MV3 adaptation](EXTENSIONS.md#pinned-gecko-port-disable-comparison-october-1). Neither engine observation proves universal extension compatibility.

[23 refreshed pinned Zen captures](https://github.com/super-original/serein-browser/actions/runs/36794469990/artifacts/11133112384) retain verified file hashes and inspected light/dark/folder states. [Committed comparisons](evidence/2026-09-30/folders-and-safari/README.md) document blank WebKit content and deliberate native material differences.

## Historical timeout follow-up (resolved at 7d87985)

At `4a1a6ba`, [run 36806503910](https://github.com/super-original/serein-browser/actions/runs/36806503910) built and packaged but the main runtime fixture timed out without aggregate results. Its retrieved timeout screenshot shows native New Tab chrome, a blank content region and no permission prompt. Later crash/download checks also failed; the surviving main fixture may have interfered, so these are not yet isolated regressions. The later `7d87985` checkpoint above supersedes this partial run.

Follow-up bounds public background-load completion to five seconds, saves explicitly partial results between scenario groups, records the launched app's own PID and stops only that executable/root/start-time identity before independent scenarios. Local process tests prove refusal of a changed identity, termination of the owned child and harmless handling of its exited PID. The final runtime gate still requires complete results; partial files never count as success.

At `50bc1e6`, [run 36807998338](https://github.com/super-original/serein-browser/actions/runs/36807998338) passes 117 unit tests but the main app exits in `ExtensionVerification` without complete results. The last partial checkpoint is 218/227, including all 17 drag and 8 subframe-consent checks; partial results are not acceptance. Its final desktop screenshot was retrieved and inspected and contains no app window. Independent crash 7/7, quit 13/13, download restart 17/17 and bridge 12/12 pass; fresh fullscreen is 0/12 on this run. Subsequent inspection of its WebGPU fullscreen screenshot shows an overlaid “Serein quit unexpectedly” notice, so these fresh fullscreen results are contaminated by the earlier crash. No confirmed crash root cause follows from the last stage alone.

The new Firefox-origin path is being moved into separately supervised controlled/real-package processes; normal installation retains default origins until its behavior is verified. Public `WKWebExtensionContext.baseURL` documents custom schemes, and uBO Lite selects behavior by its resource scheme, but this does not establish runtime correctness. Core origin validation tests pass; the host path remains experimental. The extension panel explicitly warns that background requests may retain access after site denial in this build. No compatibility or permission-enforcement success is inferred from this pending change.

## Tab placement and isolated-origin checkpoint

At `54c6c5e`, [run 36808990410](https://github.com/super-original/serein-browser/actions/runs/36808990410) passes **120 unit tests**. The partial main checkpoint is **220/229**, including **19/19 drag checks**: actual upper-half cross-window insertion and lower-half insertion after the last row, with the same live document/history preserved. The main run later times out in signed-update verification; it is not a completed browser gate. Its retrieved timeout screenshot shows the 1.1→1.2 update sheet waiting. Inspection found that a newly added window-wide unavailable-extension error could be mistaken for update consent. Follow-up renders that failure within the affected tab, identifies update sheets and records update checkpoints.

Independent crash recovery **7/7**, quit **13/13**, download restart **17/17** and bridge **12/12** pass. The isolated custom-origin processes fail with exit signals 5 and 11; the controlled probe's last stage is context loading. Public source inspection identified omitted required scheme registration; the follow-up uses the documented registration API. No custom-origin or real-blocker compatibility is claimed before the corrected probe runs.

## Earlier verified native messaging (`029feec`)

All **40 production native-host checks** pass across signed MV2/MV3 fixtures: real native consent/cancellation; owner-only persistent registration; one-shot child execution and cleanup; MV2 background-page/MV3 worker execution; ordered persistent-port messages and caller origin; unknown-host denial; permission revoke/regrant; registration revocation; extension disable and removal. The separate quit process opens a real native port, exercises cancel/stale/fresh consent, then verifies successful app exit, saved tabs and absence of its recorded child PID.

[Actual consent and registered-host screenshots](evidence/2026-09-30/native-hosts/README.md) were retrieved and inspected. A stale update-test error appears in the panel; the next revision clears stale errors during registration. Private access, Firefox host identities, automatic host discovery, native-initiated reconnect, broad real-application compatibility and Safari native formats remain unsupported or unverified. Protocol/resource limits remain explicit in [EXTENSIONS.md](EXTENSIONS.md). No universal compatibility follows from these controlled fixtures.

All 12 runtime-port checks pass on this run. MV2 disable-disconnect was intermittent at `3209fee`; multi-recipient differences and worker suspension/wakeup conformance remain unverified.

## Retained failures and graphical evidence

The `f8e857d` production checkpoint retains 30 browser failures (the sender fixture interference is repaired): nine ordinary/Glance fullscreen, two absent zoom events, two empty `about:blank` populated URLs, two port-disable lifecycle checks and 15 network/cookie boundary checks. The separate experimental Firefox-origin uBO Lite options exchange timed out at `e2339f2` and passed at `47c6c1a`; its timing reliability remains unverified. The separate **actual desktop rendering gate fails**, with zero fixture-content glyph pixels. Plain WKWebView and Apple-signed Safari reproduce IOSurface failures. No second supported free macOS 27 runtime has been identified; no private flags, security weakening, lower deployment target or engine substitution is used. [Prepared upstream report](MACOS27_RENDERING_REPORT.md) has not been posted.

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
| P1 | Zen parity | Live folder providers, custom icons/share/import, cross-window folder trees and drag-to-create-window, split-group tabs, incremental divider trees, compact variants, nested previews, profiles and sync. Basic nested folders and conversion now pass controlled checks. |
| P1 | Permissions/media/recovery | Hardware capture/location, broader subframe consent and rendered fullscreen/media. Controlled requesting-frame consent and actual attributed process-crash recovery now pass. |
| P2 | Durability and memory | Cross-launch navigation stacks, safe automatic suspension and broader subprocess-aware performance measurement; pause-on-quit now passes. |
| P2 | Visual/accessibility/distribution | Dark/inactive/AX inspection, remaining focus/menu semantics, installation validation, signing/notarization. |

Most browser checks are in-process integration scenarios. Actual keyboard input and separately supervised quit are labeled. Screenshots are retrieved and inspected. Early performance samples include WebKit subprocesses, but failed rendering prevents representative performance claims. Only standard free runners are used; no user-Mac work.

## Current follow-up

Native divider layout, document-bound port setup, native Reload/document recovery, download termination and native Glance control input have run. Selected-tab group dragging, extension action gating and the real-package rule/sender investigations are the current follow-ups. Process injection uses only a fresh fixture app, requires matching responsibility PID and executable path immediately before each exact-PID signal, and never falls back to a process-name kill. Native error Reload receives an accessibility identifier and actual AX input; screenshots are captured before and after recovery.

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

`saveNow` now reports success. Both immediate and asynchronous quit paths retain the app and surface the save error when the session cannot be committed. Native messaging accepts new connections again after cancellation. A controlled test obstructs only its isolated `session.json` destination, confirms the app and edited tabs survive the failed quit, repairs the obstruction, requires fresh consent and checks the final saved session and real process exit. Ordinary and active-native-host variants pass at `12ad6aa`; the combined independently supervised quit suite is 13/13.

### October 1 measured workload limits

At verified `12ad6aa` ([run 36801871259](https://github.com/super-original/serein-browser/actions/runs/36801871259)), 67 integration-workload process samples report median aggregate RSS **411.48 MiB**, peak **513.56 MiB** and median summed lifetime-average CPU **1.8%**. A separate nine-second warm-idle interval over six processes common to both endpoints reports **0.56% interval CPU** and median RSS **382.61 MiB**. These are single-run diagnostics on virtualized ARM64 hardware, not performance acceptance. The sampler includes Serein and newly appearing WebKit services by baseline PID difference; it does not establish exact service ownership, RSS can double-count shared pages, and endpoint CPU excludes short-lived processes. Website desktop composition is broken, so representative scrolling/rendering, energy and physical-Mac efficiency remain unverified. Raw samples and limitations are in the linked evidence artifact's `runtime/performance.json` and `runtime/idle-performance.json`.

Delayed crash diagnostics now retain only reports matching recorded fixture PIDs. The fullscreen supervisor checks for the exact Serein crash notice, captures it, and uses Ignore before independent input; it never uses Reopen, dismisses other applications' notices or disables crash reporting globally. The main crash/failure stays recorded. This follows actual screenshot evidence, not a hypothetical platform adjustment.

At `7d87985`, the 12-second, three-tab warm-idle sample reports **395.25 MiB median RSS and 0.5% interval CPU** across six processes present at both endpoints. The full mixed integration workload reports 58 samples, 395.39 MiB median and 1,366.56 MiB peak RSS. These include attributed WebKit subprocesses, may double-count shared pages, and run with broken desktop rendering on virtualized CI. They are workload observations, not energy, physical-memory, or representative browsing claims.

### Opt-in idle suspension follow-up

The pending production policy adds Off/15/30/60-minute settings, activity tracking, once-per-minute checks, public media/capture queries with timeout, and revalidation before releasing a page. Tests use an isolated browser manager and actual local pages for no-media unloading, object release and navigation/zoom restoration. Unknown/playing/paused states and activity/navigation/selection races use explicitly controlled query responses; active-download exclusion uses a controlled download record. Private pages, previews, edited and pinned tabs are excluded. Results and the settings screenshot await exact-head execution; no hardware media or memory-performance pass is inferred.

A follow-up original audio fixture generates one second of quiet PCM on the loopback server. Native pointer input starts playback; advancing media time and a trusted event precede public playing/paused-state and inactive-tab retention checks. This is pending runner execution and does not claim physical speaker, microphone/camera or screen-capture verification. Local GET/HEAD/range/error checks validate only the fixture transport.

Pending follow-up also measures idle age with ContinuousClock, so wall-clock adjustments cannot prematurely age an inactive page.

## Pending page screenshot command

Tools → Save Page Screenshot uses the real selected WKWebView viewport and a native PNG destination sheet. Nothing is written on cancellation or after a changed document/selection; private-window exports require the same explicit destination choice with a disk-persistence warning. Runtime scenarios cover PNG encoding, stale capture identity, cancellation, duplicate-command refusal, native save destination/content and private cancellation. The pending image is an internal WebKit snapshot, explicitly not evidence that desktop content rendering is repaired.


## Historical navigation/performance preparation notes (superseded by 69e6b04)

## Pending production navigation persistence

The next change moves same-build HTTP(S) Back/Forward restoration from a fixture into an opt-in setting. It stores bounded, checksummed state atomically with the normal session, excludes private and edited pages, checks initial and committed history URLs, and falls back to the current URL for invalid or mismatched state. Six unit tests cover legacy sessions, privacy/identity, credentials, corruption, malformed optional data and size limits. The supervised fixture now performs five independent launches through production save/restore, including disabled preference, changed engine and corrupt checksum cases. At d4ebe44 all six new unit tests and all 19 production restart/fallback checks pass. The next iteration additionally unloads the background history tab before saving and verifies that disabled preference removes the payload; both follow-ups pass at 8c76795.

### Additional history privacy checks prepared

The next fixture keeps a real private WKWebView with nonempty interaction state alive during a normal session save, then confirms its window/history are absent. It dispatches a real document input event through the existing isolated edit bridge, verifies opaque persistence is suppressed, reloads and checks that Back/Forward entries survive. These runtime additions are pending; model-level privacy/identity tests already pass.

### Native tab-switch measurement prepared

A controlled four-tab/24-switch fixture measures native WKWebView attachment followed by a document-identity JavaScript roundtrip, recording each sample and median/nearest-rank p95. It has bounded waits and verifies the selected document every time; no timing threshold is used as a pass/fail gate. Ten-millisecond polling, existing workload and the failed desktop compositor are explicit limitations. This is not visible-frame latency, startup, scrolling or energy evidence. Runtime results are pending.
