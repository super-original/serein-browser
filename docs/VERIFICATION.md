# Verification and continuation backlog

Full original-spec completion remains the goal and is not achieved. [Draft PR #1](https://github.com/super-original/serein-browser/pull/1) is unmerged. [Historical checkpoints](VERIFICATION_HISTORY.md) retain previous results and failed experiments.

## Latest verified source

`383846a37c4940c2ee9fa1460fb391fa2a0229ea`: [run 36770920287](https://github.com/super-original/serein-browser/actions/runs/36770920287) passes **68 unit tests, 338/351 browser checks, ten independent download-restart checks, four independent quit checks and 12 bridge checks**. Actual environment: macOS 27.0 26A428, Xcode 27.1 27A9269, Swift 6.4, SDK/minimum 27.0, ARM64.

[Download app](https://github.com/super-original/serein-browser/actions/runs/36770920287/artifacts/11124585138) · [Evidence](https://github.com/super-original/serein-browser/actions/runs/36770920287/artifacts/11124156390). Ad-hoc signed/hardened; not Developer ID signed or notarized. Development candidate with known defects.

Normal paused downloads resume in a new app process with full 8 MiB byte integrity. Private resume data/history stay off disk; owner-only file permissions and completion/cancellation cleanup pass. Active downloads without saved resume data still become interrupted. The inspected Downloads screenshot now describes this relaunch behavior correctly.

Extension recovery passes complete back/forward URL-list, current-position and zoom preservation, plus exactly one options-script initialization per page across initial and three repeated cycles. Public navigation preferences suppress scripts during the transient real-resource preload. Find checks including actual Command-F, query entry, Escape and subsequent web-page key delivery, native/extension-window consent, actual quit/session saving, balanced four-pane grids, minimum-window bounds and keyboard/menu extension commands pass. Window lifecycle and populated URLs for granted HTTP pages pass through MV2/MV3 JavaScript APIs.

All 19 existing Glance checks pass, including actual Option-click, both Control-Tab directions, Escape, returned page-key delivery, live expansion/split/movement, consent, private isolation and reopened relationships. All new popup checks pass: the reopened owner attaches at 756×661, a real external-host link opens the essential's preview, its store is shared correctly, its native message controller is distinct, and closing it preserves parent edit tracking. The `c136b59` capture 34 was inspected and shows the actual preview and essential badge. Unprimed ordinary/Glance fullscreen entry still fails with InvalidStateError despite trusted input and active user activation. A standard WebGL context succeeds, after which native fullscreen entry and Escape pass (four checks); the later WebGPU scenario also passes four checks, but its adapter request returns null and may inherit WebGL initialization. Twelve of 39 process samples now contain WebKit.GPU. All four GPU-probe screenshots were retrieved and inspected: ordinary page bodies remain white and fullscreen captures are black. Native state/DOM fullscreen success does not prove rendered fullscreen content. The nine unprimed fullscreen failures remain. All 12 bridge checks pass. The four other browser failures are missing MV2/MV3 `tabs.onZoomChange` and empty `about:blank` URLs in populated-window results. The separate **actual desktop rendering gate fails** with zero content glyph pixels. DOM/internal snapshots are not desktop-rendering evidence. Plain WKWebView and Apple-signed Safari reproduce IOSurface failures on this free runner. No supported second free macOS 27 image has been identified; no private flags, security weakening, lower deployment target or engine substitution is used. [Prepared upstream report](MACOS27_RENDERING_REPORT.md) has not been posted.

Downloads and extension-management screenshots from the preceding `4449c7a` checkpoint were retrieved and inspected. Earlier inspected native-grid geometry has eight-point column gaps and 327/326-point rows. [Side-by-side original screenshots and measurements](evidence/2026-09-30/grid/README.md) compare the pinned Zen baseline with explicit focus/sidebar differences. WebKit page bodies remain blank.

## Current work under verification

Fresh app processes now isolate no-primer, WebGPU-first and WebGL-first scenarios, each with actual clicks, Escape, screenshots and process samples. No production pages or security settings are modified. This is a causal diagnostic, not a rendering workaround.

App-owned persistence now uses a shared private-directory/atomic-record writer (0700 directory, 0600 records) for session, library, permissions, extension records and download metadata/resume data. User-selected downloaded files are untouched. Two core tests cover migration/replacement and invalid-parent preservation; real download restart checks now inspect on-disk modes after both launches. These changes await exact-head macOS CI. [Inspected original Glance comparison](evidence/2026-09-30/glance/README.md) retains its earlier exact source and limits. Full original-spec completion remains the goal.

## Prioritized remaining work

| Priority | Requirement | Completion evidence still needed |
|---|---|---|
| P0 | Actual macOS 27 desktop rendering | Genuine rendered pages in real screenshots and a passing retained glyph gate; current free-runner system WebKit failure persists. |
| P0 | Full extension compatibility | [Exact formats/APIs and seven real-package rejections](EXTENSIONS.md). Native Safari/legacy formats, missing engine APIs, production native messaging and broad real-extension semantics remain unsupported or unverified. |
| P1 | Grid/native interaction | Broader resizing, dark/inactive and keyboard/AX inspection; broader windows API semantics. Balanced initial geometry, minimum bounds, history/zoom and command delivery now pass. |
| P1 | Zen parity | Split-group tabs, incremental divider trees, compact toolbar variants, Glance, folders/groups, profiles, import and sync. [Checklist](ZEN_PARITY.md) distinguishes implemented/partial/missing. |
| P1 | Permissions/media/recovery | Physical capture/location behavior, broader subframe consent, fullscreen/media and actual process-crash recovery. Policy-only tests do not establish hardware behavior. |
| P2 | Durability and memory | Full history-stack restoration, automatic suspension preserving media/unsaved work, and automatic pause-on-quit. Normal download history and explicit paused-download recovery across launches are verified. |
| P2 | Visual/accessibility/performance/distribution | Light/dark/inactive/accessibility inspection, representative subprocess-aware benchmarks after rendering works, signing/notarization and installation validation. Only free runners; no user-Mac work. |

## Evidence conventions

Most browser scenarios are in-process integration tests; native keyboard tests and separately supervised quit are labeled. Delegate tests are not JavaScript promise tests. Captures are retrieved and inspected, and screenshot existence alone is never a visual pass. Early diagnostic performance samples include WebKit subprocesses but failed rendering prevents representative browser performance claims. No significant unsupported requirement is waived by a passing compilation or package.
