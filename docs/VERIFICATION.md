# Verification and continuation backlog

This browser is not complete. A passing build is not a production or extension-compatibility claim.

## Latest continuation checkpoint

`cfc333d` [run 36717038331](https://github.com/super-original/serein-browser/actions/runs/36717038331) passed 33 unit tests and recorded **136/138 passing browser checks before the native-message experiment**. Native Save-panel keyboard selection, exact destination/content, cancellation and stale tab/document navigation confirmation passed; the Save-panel screenshot was inspected. Both extension multiselection query assertions failed. The isolated probe then terminated during fixture loading without final results; it is being moved into a separate process/required CI step. This checkpoint does not replace a fully passing runtime run or establish native-message support. The real desktop gate remains failed. Current-head results and downloadable baseline are distinguished in [draft PR #1](https://github.com/super-original/serein-browser/pull/1).

## Baseline audit (2026-09-30)

The saved checkout and remote `main` both resolve to `8fcac24225c0cee2dde32ae0b5b8649bc2ee1706`. There were no open or closed PRs and no newer build runs at audit time. The September 17 [run](https://github.com/super-original/serein-browser/actions/runs/35246339695) passed build/unit/package and integration steps but failed **Gate actual desktop rendering**. Its diagnostic artifact has expired; the app artifact is not being preserved as requested. A fresh [baseline run](https://github.com/super-original/serein-browser/actions/runs/36704547843) passed all 43 app scenarios but reproduced the rendering failure on macOS 27 `26A428`.

Implemented code and prior evidence cover navigation, basic tabs/workspaces, two-pane splits, persistence, private data stores, downloads and a limited system-WebKit extension host. See [Zen parity](ZEN_PARITY.md) and [extension scope](EXTENSIONS.md); their partial/unsupported entries remain requirements.

## Prioritized backlog

| Priority | Work | Evidence / completion bar |
|---|---|---|
| P0 | Establish actual page rendering | Inspect fresh desktop and direct-AppKit captures; retain the failing gate until genuine page rendering passes. Do not replace desktop evidence with WebKit snapshots. |
| P0 | Site permission policy | Implemented and exercised: exact-origin/capability policies, private isolation, settings/reset and stale-prompt protection. Real hardware capture/location consent remains unverified. |
| P1 | Session/split lifecycle | Focus/close/workspace/restore regressions fixed and tested; active-pane geometry inspected. Full split groups, window history stacks and broader AX interactions remain gaps. |
| P1 | Native interaction and Zen comparisons | Inspect matched light/dark, compact, split and settings states; expand keyboard/AX and accessibility coverage. |
| P1 | Extension semantic coverage | Package-loading audits are not functionality tests. Implement/test lifecycle, host APIs and permission boundaries; retain native Safari/CRX/legacy restrictions explicitly. |
| P2 | Durable downloads, suspension, richer Zen parity | Normal download history and in-memory resume are implemented; cross-launch resume, automatic media/unsaved-state-aware suspension, Glance, groups/folders, profiles, import and sync remain absent or partial. |
| P2 | Distribution and performance | App is ad-hoc signed, not notarized; measure subprocess resources after reliable rendering. No paid runner or local Mac work. |

## Evidence conventions

CI records runtime/SDK/compiler/architecture and Mach-O deployment target. App integration checks are in-process scenarios, except explicitly labeled native keyboard checks. Capture existence and DOM/title checks do not prove rendered content. The glyph-presence gate detects a blank-page regression; it does not establish Zen fidelity or accessibility. Site-permission store checks do not prove physical camera, microphone or location delivery on a hosted VM.


## Verified continuation

[Run 36706449602](https://github.com/super-original/serein-browser/actions/runs/36706449602) tests commit `ea3a4a0d4416c86033ad38094e30ef388ce6e5b1`: **26 unit tests and all 65 actual-app integration checks pass**. Release packaging/signature/deployment checks pass. The overall workflow correctly **fails** the desktop rendering gate (`darkContentPixels: 0`, required >1000).

Verified new scope: exact-origin/capability policy separation, combined media decisions, persistence/reset, private-normal and private-private isolation, native consent-sheet presentation, Allow Once without persistence, stale prompt rejection, split focus/state preservation, required extension permission admission, production disable/remove paths and local-storage reset after reinstalling MV2/MV3 fixtures under the identical UUID. Both fixture counters restart at 1. In-process sheet responses do not establish AX consent automation or physical camera/microphone/location delivery.

The same run's warm-idle diagnostic samples **314.99 MiB summed RSS** and **1.11% interval CPU** over 9 seconds, including the app and WebKit subprocesses. Conditions include the deterministic fixture, several tabs, and a hidden diagnostic WebKit window. RSS may double-count shared memory; CPU includes processes present at both sample endpoints. Failed desktop rendering invalidates a normal browser workload comparison. These are diagnostic measurements, not performance or energy claims.

The [platform probe](https://github.com/super-original/serein-browser/actions/runs/36705841148) proves the same blank-page defect in system Safari and an unhardened WKWebView witness. [All 14 refreshed Zen references](https://github.com/super-original/serein-browser/actions/runs/36705707876) were visually inspected; the same fixture renders in Zen. [Retained inspected comparisons](evidence/2026-09-30/README.md) show the evidence directly.

Native permission settings and consent sheets were inspected, as were focused primary/secondary split outlines. Inspection found an extra titlebar-safe-area inset inside native split panes. [Run 36707376209](https://github.com/super-original/serein-browser/actions/runs/36707376209), exact commit `acf9bebd0d6f03ed2104b27af47a0bfe48f87951`, passed the same 26 unit and 65 app checks. Its inspected captures confirm the corrected eight-point page inset and focus outline moving between panes. Web content is still blank and the rendering gate still fails.

Full extension compatibility remains unmet: all seven pinned real packages are rejected for exact reasons in [the current matrix](EXTENSIONS.md#current-real-package-admission-results). Safari native/legacy formats and unsupported engine API semantics have not been implemented. Full Zen parity, accessibility states, media/device behavior, crash injection, normal-workload performance and signed/notarized distribution remain release blockers. No claim that independent backlog items are complete is implied by the platform failure.


The error-state capture also exposed a recovery defect: failed navigation could show the previous committed URL, and Reload could reload that old page. The continuation now retains provisional/failed destinations, routes toolbar/menu/error-button reload through the failed target, and adds explicit failed-address/retry scenarios. Download responses clear provisional navigation state instead of replacing the current tab destination. Latest exact-commit results are recorded in [draft PR #1](https://github.com/super-original/serein-browser/pull/1); the prior verified runs above are kept as historical evidence.

Commit `105b9f5cdfc9482cf8f3ec1a3eceb6cfc24e3679`: [run 36707859265](https://github.com/super-original/serein-browser/actions/runs/36707859265) passed 26 unit tests and all 67 runtime checks, including failed-destination retention and retry. The actual desktop gate still fails. The inspected [network-error screenshot](evidence/2026-09-30/navigation-error.png) shows the unavailable destination in the address field and native recovery UI. [Download this tested ARM64 application](https://github.com/super-original/serein-browser/actions/runs/36707859265/artifacts/11091774981); ad-hoc signed, not notarized, macOS 27 minimum, rendering failure unresolved.

The next permission follow-up, `0b6623b`, passed all 73 runtime checks in [run 36708785208](https://github.com/super-original/serein-browser/actions/runs/36708785208), including persisted extension revocation and restored denied-host injection for MV2/MV3. The rendering gate remained failed. A subsequent unload guard also protects the unfocused primary split pane and revalidates visibility after confirmation; exact-head CI will verify these regressions.

`41f6261` passed 28 unit tests and 88 runtime checks in [run 36709589360](https://github.com/super-original/serein-browser/actions/runs/36709589360): visible split-pane unload protection, confirmation-time selection revalidation, and actual MV2/MV3 tabs create/get/duplicate/remove with pinned state, URL/identity and created/removed events. The selected split desktop capture was inspected. `74977b2` [run 36709877579](https://github.com/super-original/serein-browser/actions/runs/36709877579) additionally verifies workspace address/selection synchronization and automatic permission-notification persistence. The desktop rendering gate remains failed. A reviewable [upstream rendering report](MACOS27_RENDERING_REPORT.md) is prepared but has not been posted.

Download follow-up under verification: production WKDownload delegate/store, durable normal history, explicit interrupted state after relaunch, progress, in-memory pause/resume when WebKit supplies resume data, private-window record ownership and closure cleanup. A slow deterministic HTTP Range fixture verifies real resumption and full byte integrity. Destination selection is injected in these integration cases; native Save-panel automation and resume across application launches are not claimed.

`4302e2c` [run 36712466648](https://github.com/super-original/serein-browser/actions/runs/36712466648) passed 30 unit tests and all 115 runtime checks. The production download store/delegate completed and restored normal history, isolated private owners, excluded private records from disk, retired an active private download on window closure, paused/resumed an actual 8 MiB range-capable transfer with full byte integrity, rejected resumption through a private context, and discarded paused resume state on cancellation. The desktop rendering gate still failed.
