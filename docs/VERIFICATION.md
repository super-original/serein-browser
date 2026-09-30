# Verification and continuation backlog

Full original-spec completion remains the goal and is not achieved. [Draft PR #1](https://github.com/super-original/serein-browser/pull/1) is unmerged. [Historical checkpoints](VERIFICATION_HISTORY.md) retain previous results and failed experiments.

## Latest verified source

`502207897435bffb51d1a3099e9516b9c06e1b09`: [run 36758205114](https://github.com/super-original/serein-browser/actions/runs/36758205114) passes **58 unit tests, 291/303 browser checks, four independent quit checks and 12 bridge checks**. Actual environment: macOS 27.0 26A428, Xcode 27.1 27A9269, Swift 6.4, SDK/minimum 27.0, ARM64.

[Download app](https://github.com/super-original/serein-browser/actions/runs/36758205114/artifacts/11117407734) · [Evidence](https://github.com/super-original/serein-browser/actions/runs/36758205114/artifacts/11117227944). Ad-hoc signed/hardened; not Developer ID signed or notarized. Development candidate with known defects.

Previously verified at `21be7ae`: complete back/forward URL-list, current-position and zoom preservation across initial and three repeated extension recoveries; seven Find checks; eight extension-window close delegate checks; native window/quit consent with process exit/session save; selected-tab grids, balanced divider geometry, minimum-window bounds, focus, unload protection and closure. Actual keyboard commands, management-menu dispatch and private-window exclusion pass for MV2/MV3. These narrow fixtures do not establish universal extension compatibility.

The twelve browser failures include missing MV2/MV3 `tabs.onZoomChange`, two populated-window `about:blank` URL assertions (one tab is returned, but its URL is empty), one intermittent Find focus failure, three repeated recovery failures from the inert-preload experiment, and four initialization-count checks. The latter incorrectly used old signed archives; regenerated archives are required to exercise the counters. The final recovery error screenshot was retrieved and inspected. Prior real-resource recovery at `21be7ae` passed history/zoom checks, but duplicate script initialization was unmeasured. Window creation, size-only bounds, resizing, focus, removal, private-denial and created/removed events pass through actual MV2/MV3 JavaScript APIs. The separate **actual desktop rendering gate fails** with zero content glyph pixels. DOM/internal snapshots are not desktop-rendering evidence. Plain WKWebView and Apple-signed Safari reproduce IOSurface failures on this free runner. No supported second free macOS 27 image has been identified; no private flags, security weakening, lower deployment target or engine substitution is used. [Prepared upstream report](MACOS27_RENDERING_REPORT.md) has not been posted.

Grid, minimum-window and extension-management screenshots were inspected. Native grid columns now have eight-point gaps, with 327/326-point rows. [Side-by-side original screenshots and measurements](evidence/2026-09-30/grid/README.md) compare the inspected fresh Zen reference; their sidebar/focus differences are explicit. Page bodies remain blank.

## Current work under verification

Pending follow-up: real-resource preload with public per-navigation JavaScript suppression, regenerated signed fixtures/counters, Find focus restoration after view removal, and granted-HTTP populated-window coverage while retaining the failing `about:blank` assertion. Cross-launch normal-download resume persistence and a two-process byte-integrity/privacy gate require a fresh exact-head run.

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
