# Continuation goal

Deliver a reviewable macOS 27/ARM64 WebKit build with durable permission consent, reliable split/navigation recovery, and a source-backed resolution path for every observed real-extension rejection; prove behavior with exact-commit tests and inspected desktop evidence.

This goal was explicitly requested September 30, 2026. No native task goal-setting capability is exposed to this execution environment. This versioned document and the task plan track it instead.

The overarching requirement remains a production-quality native browser reproducing Zen's layout and interactions with macOS 27 Liquid Glass and full Chrome, Firefox, and Safari extension compatibility. This continuation milestone does not redefine that requirement or turn partial support into completion.

## Acceptance criteria and proof

- Site camera/microphone/location consent is scoped by top-level and requesting origin, persists only in normal browsing, supports revocation, and rejects stale navigation prompts. Core tests, real native consent-sheet scenarios, private isolation checks, and inspected captures provide evidence; physical capture and TCC still require validation.
- Split selection preserves both pane identities when unrelated tabs close; the selected pane and address are coherent; failed navigation retains and retries its destination. Unit/runtime checks plus inspected matched-geometry screenshots prove the implemented paths.
- Extension grants, denials, removals, and expiration survive disk round-trip without restoring revoked install grants or persisting activeTab gestures. MV2 and MV3 runtime fixtures must prove restored denial prevents injection.
- Every rejection among the seven pinned real packages has a concrete host/engine/format classification. Fix feasible compatibility defects without dropping required permissions, weakening isolation, or claiming load-only checks establish functional compatibility. Record exact versions, hashes, normalized metadata, and remaining missing APIs.
- Preserve the macOS 27 minimum, WebKit engine, and free standard GitHub runner constraints. Investigate supported rendering alternatives. A real desktop screenshot showing fixture content must pass the unchanged rendering gate before marking rendering verified. Safari/plain-WKWebView failures and internal snapshots are diagnostic evidence only.
- Publish a draft PR, exact tested commit/run, downloadable ad-hoc-signed app, source-linked findings, and inspected raw screenshots. Keep all failing and unverified requirements visible. Clean only obsolete task artifacts; retain this active primary checkout.

## Current evidence and open work

- `105b9f5`: 26 unit tests and 67 runtime checks passed; actual rendering gate failed. [Run and app](https://github.com/super-original/serein-browser/actions/runs/36707859265).
- Permission persistence follow-up is under macOS CI verification. Reserved action-command normalization is being implemented with controlled fixtures and pinned real-package audit.
- Desktop WebKit rendering, full extension compatibility, complete Zen parity, physical device permission behavior, and representative performance validation remain open. See [verification backlog](VERIFICATION.md), [extension matrix](EXTENSIONS.md), and [parity checklist](ZEN_PARITY.md).
