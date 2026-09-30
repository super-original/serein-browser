# Verification and continuation backlog

This browser is not complete. A passing build is not a production or extension-compatibility claim.

## Baseline audit (2026-09-30)

The saved checkout and remote `main` both resolve to `8fcac24225c0cee2dde32ae0b5b8649bc2ee1706`. There were no open or closed PRs and no newer build runs at audit time. The September 17 [run](https://github.com/super-original/serein-browser/actions/runs/35246339695) passed build/unit/package and integration steps but failed **Gate actual desktop rendering**. Its diagnostic artifact has expired; the app artifact is not being preserved as requested. A fresh [baseline run](https://github.com/super-original/serein-browser/actions/runs/36704547843) was requested to obtain current evidence.

Implemented code and prior evidence cover navigation, basic tabs/workspaces, two-pane splits, persistence, private data stores, downloads and a limited system-WebKit extension host. See [Zen parity](ZEN_PARITY.md) and [extension scope](EXTENSIONS.md); their partial/unsupported entries remain requirements.

## Prioritized backlog

| Priority | Work | Evidence / completion bar |
|---|---|---|
| P0 | Establish actual page rendering | Inspect fresh desktop and direct-AppKit captures; retain the failing gate until genuine page rendering passes. Do not replace desktop evidence with WebKit snapshots. |
| P0 | Site permission policy | Add exact-origin/capability policies, private isolation, settings/reset and stale-prompt protection; unit and app runtime coverage. Real hardware capture/location consent remains separate. |
| P1 | Session/split lifecycle | Repair stale pane IDs and verify switching, close, workspace moves and restore with both panes focused. |
| P1 | Native interaction and Zen comparisons | Inspect matched light/dark, compact, split and settings states; expand keyboard/AX and accessibility coverage. |
| P1 | Extension semantic coverage | Package-loading audits are not functionality tests. Implement/test lifecycle, host APIs and permission boundaries; retain native Safari/CRX/legacy restrictions explicitly. |
| P2 | Durable downloads, suspension, richer Zen parity | Resume/history, media/unsaved-state-aware suspension, Glance, groups/folders, profiles, import and sync remain absent or partial. |
| P2 | Distribution and performance | App is ad-hoc signed, not notarized; measure subprocess resources after reliable rendering. No paid runner or local Mac work. |

## Evidence conventions

CI records runtime/SDK/compiler/architecture and Mach-O deployment target. App integration checks are in-process scenarios, except explicitly labeled native keyboard checks. Capture existence and DOM/title checks do not prove rendered content. The glyph-presence gate detects a blank-page regression; it does not establish Zen fidelity or accessibility. Site-permission store checks do not prove physical camera, microphone or location delivery on a hosted VM.
