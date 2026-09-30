# Verification and continuation backlog

Full original-spec completion remains the goal and is not achieved. [Draft PR #1](https://github.com/super-original/serein-browser/pull/1) is unmerged. [Historical checkpoints](VERIFICATION_HISTORY.md) retain previous results and failed experiments.

## Latest verified source

`21be7aed0e9c0b65a8668739781e1acbc6b2ab41`: [run 36756928826](https://github.com/super-original/serein-browser/actions/runs/36756928826) passes **58 unit tests, 295/299 browser checks, four independent quit checks and 12 bridge checks**. Actual environment: macOS 27.0 26A428, Xcode 27.1 27A9269, Swift 6.4, SDK/minimum 27.0, ARM64.

[Download app](https://github.com/super-original/serein-browser/actions/runs/36756928826/artifacts/11117666284) · [Evidence](https://github.com/super-original/serein-browser/actions/runs/36756928826/artifacts/11117960756). Ad-hoc signed/hardened; not Developer ID signed or notarized. Development candidate with known defects.

Verified additions: complete back/forward URL-list, current-position and zoom preservation across initial and three repeated extension recoveries; seven Find checks; eight extension-window close delegate checks; native window/quit consent with process exit/session save; selected-tab grids, balanced divider geometry, minimum-window bounds, focus, unload protection and closure. Actual keyboard commands, management-menu dispatch and private-window exclusion pass for MV2/MV3. These narrow fixtures do not establish universal extension compatibility.

The four browser failures are missing MV2/MV3 `tabs.onZoomChange` and two populated-window tab assertions under investigation. Window creation, size-only bounds, resizing, focus, removal, private-denial and created/removed events pass through actual MV2/MV3 JavaScript APIs. The separate **actual desktop rendering gate fails** with zero content glyph pixels. DOM/internal snapshots are not desktop-rendering evidence. Plain WKWebView and Apple-signed Safari reproduce IOSurface failures on this free runner. No supported second free macOS 27 image has been identified; no private flags, security weakening, lower deployment target or engine substitution is used. [Prepared upstream report](MACOS27_RENDERING_REPORT.md) has not been posted.

Grid, minimum-window and extension-management screenshots were inspected. Native grid columns now have eight-point gaps, with 327/326-point rows. [Side-by-side original screenshots and measurements](evidence/2026-09-30/grid/README.md) compare the inspected fresh Zen reference; their sidebar/focus differences are explicit. Page bodies remain blank.

## Current work under verification

Pending follow-up: inspect populated-window tab payloads without relaxing their assertions; use an inert preload for extension history restoration and verify that each recovered options page initializes exactly once. The previous resource preload may execute startup scripts twice. These changes require a fresh exact-head run.

## Prioritized remaining work

| Priority | Requirement | Completion evidence still needed |
|---|---|---|
| P0 | Actual macOS 27 desktop rendering | Genuine rendered pages in real screenshots and a passing retained glyph gate; current free-runner system WebKit failure persists. |
| P0 | Full extension compatibility | [Exact formats/APIs and seven real-package rejections](EXTENSIONS.md). Native Safari/legacy formats, missing engine APIs, production native messaging and broad real-extension semantics remain unsupported or unverified. |
| P1 | Grid/native interaction | Broader resizing, dark/inactive and keyboard/AX inspection; JavaScript windows lifecycle. Balanced initial geometry, minimum bounds, history/zoom and command delivery now pass. |
| P1 | Zen parity | Split-group tabs, incremental divider trees, compact toolbar variants, Glance, folders/groups, profiles, import and sync. [Checklist](ZEN_PARITY.md) distinguishes implemented/partial/missing. |
| P1 | Permissions/media/recovery | Physical capture/location behavior, broader subframe consent, fullscreen/media and actual process-crash recovery. Policy-only tests do not establish hardware behavior. |
| P2 | Durability and memory | Cross-launch download resume, full history-stack restoration, automatic suspension preserving media/unsaved work. Normal history and in-memory download resume already verified. |
| P2 | Visual/accessibility/performance/distribution | Light/dark/inactive/accessibility inspection, representative subprocess-aware benchmarks after rendering works, signing/notarization and installation validation. Only free runners; no user-Mac work. |

## Evidence conventions

Most browser scenarios are in-process integration tests; native keyboard tests and separately supervised quit are labeled. Delegate tests are not JavaScript promise tests. Captures are retrieved and inspected, and screenshot existence alone is never a visual pass. Early diagnostic performance samples include WebKit subprocesses but failed rendering prevents representative browser performance claims. No significant unsupported requirement is waived by a passing compilation or package.
