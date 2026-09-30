# Verification and continuation backlog

Full original-spec completion remains the goal and is not achieved. [Draft PR #1](https://github.com/super-original/serein-browser/pull/1) is unmerged. [Historical checkpoints](VERIFICATION_HISTORY.md) retain previous results and failed experiments.

## Latest verified source

`884d7310f5ecd40b4fffecece90923053a91f3ee`: [run 36765726140](https://github.com/super-original/serein-browser/actions/runs/36765726140) passes **67 unit tests, 323/329 browser checks, ten independent download-restart checks, four independent quit checks and 12 bridge checks**. Actual environment: macOS 27.0 26A428, Xcode 27.1 27A9269, Swift 6.4, SDK/minimum 27.0, ARM64.

[Download app](https://github.com/super-original/serein-browser/actions/runs/36765726140/artifacts/11120871388) · [Evidence](https://github.com/super-original/serein-browser/actions/runs/36765726140/artifacts/11121226085). Ad-hoc signed/hardened; not Developer ID signed or notarized. Development candidate with known defects.

Normal paused downloads resume in a new app process with full 8 MiB byte integrity. Private resume data/history stay off disk; owner-only file permissions and completion/cancellation cleanup pass. Active downloads without saved resume data still become interrupted. The inspected Downloads screenshot now describes this relaunch behavior correctly.

Extension recovery passes complete back/forward URL-list, current-position and zoom preservation, plus exactly one options-script initialization per page across initial and three repeated cycles. Public navigation preferences suppress scripts during the transient real-resource preload. Find checks including actual Command-F, query entry, Escape and subsequent web-page key delivery, native/extension-window consent, actual quit/session saving, balanced four-pane grids, minimum-window bounds and keyboard/menu extension commands pass. Window lifecycle and populated URLs for granted HTTP pages pass through MV2/MV3 JavaScript APIs.

Two Glance checks fail: both tab-cycling directions. Expansion now preserves the live view and its JavaScript state. Actual CoreGraphics Option-click (posting permission already granted), Escape dismissal, returned page-key delivery and closed-parent/preview restoration now pass. Geometry, minimum-window control bounds, same-store loading, edit-consent invalidation, live normal-window movement, split conversion and private isolation pass. Both screenshots were retrieved and inspected: all three native controls fit; page bodies remain blank. All 12 bridge checks pass after waiting for HTTP fixture readiness before launching the app. The four other browser failures are missing MV2/MV3 `tabs.onZoomChange` and empty `about:blank` URLs in populated-window results. The separate **actual desktop rendering gate fails** with zero content glyph pixels. DOM/internal snapshots are not desktop-rendering evidence. Plain WKWebView and Apple-signed Safari reproduce IOSurface failures on this free runner. No supported second free macOS 27 image has been identified; no private flags, security weakening, lower deployment target or engine substitution is used. [Prepared upstream report](MACOS27_RENDERING_REPORT.md) has not been posted.

Downloads and extension-management screenshots from this exact commit were retrieved and inspected. Earlier inspected native-grid geometry has eight-point column gaps and 327/326-point rows. [Side-by-side original screenshots and measurements](evidence/2026-09-30/grid/README.md) compare the pinned Zen baseline with explicit focus/sidebar differences. WebKit page bodies remain blank.

## Current work under verification

Follow-up handles browser shortcuts before AppKit/WebKit key-equivalent dispatch as well as normal key events; Control-Tab never reached the latter in this run. Configurable external-host previews from pinned/essential tabs are implemented with Zen's shipped enabled default and WebKit's original popup configuration/request. Real pointer-click verification and a capture are added. These changes await exact-head verification. [Inspected original Glance comparison](evidence/2026-09-30/glance/README.md) retains the exact earlier source and limitations. Full original-spec completion remains the goal.

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
