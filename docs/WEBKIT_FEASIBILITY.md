# Compatibility implementation and engine feasibility

Full extension compatibility remains the requirement. A rejected package is evidence of a missing capability, not proof that the capability cannot be implemented.

## Public system-engine route first

Browser-owned state (downloads, history, bookmarks, tab groups and sessions) can be implemented in Swift. The unresolved part is exposing the exact extension namespaces, permission semantics and events in every extension execution context, including service workers. Public `WKUserScript` injection alone does not establish worker API support.

An isolated MV2/MV3 experiment attempts to test `WKWebExtensionControllerDelegate`'s public native-message reply callback. It returns only a constant response, bound to a context identity, explicit `nativeMessaging` grant and one registered application/operation. It tests default denial and rejection of an unregistered application. Production installation still rejects native messaging. Initial combined runs terminated during bundled-fixture loading. A separate process, copied fixture directory, complete manifest metadata and registered tab/window resolved the probe setup. Run 36719132526 at `f20b79b` passed all eight MV2/MV3 transport/denial checks. This establishes only the constant-reply transport, not an API adapter. The SDK requires distinct configurations when multiple controllers coexist. A successful experiment would justify a narrowly scoped compatibility-adapter investigation, not arbitrary native-process access or a claim of implemented downloads/history APIs. Required follow-up: validate namespace installation in worker/page/isolated content worlds; host-side capability checks; argument validation; exact errors/events; revocation and private access; original-package integrity and transparent transformation policy.

Blocking request interception, Firefox DNS, service-worker lifetime and offscreen rendering need separate engine-level investigation. A native state adapter alone cannot reproduce them. SafariServices native handlers and legacy Safari formats need separate hosting/translation research; a WebKit rebuild does not automatically solve those formats.

## Measured source inventory, not a build-size claim

The [recorded inventory](evidence/2026-09-30/webkit-source-inventory.json) pins WebKit `131cc0a7111b3a8c4038989d7bd5cee49c1ad7f7`. Selected build-related Git trees contain 1,332,468,145 blob bytes (about 1.24 GiB). Truncated GitHub tree responses were expanded recursively. Reproduce with `python3 script/webkit_source_inventory.py --output inventory.json` and authenticated read-only `gh` access. This excludes Git storage, generated products, dependencies and other directories; it measures neither peak disk/RAM nor build time.

[GitHub's standard public-runner table](https://docs.github.com/en/actions/reference/runners/github-hosted-runners) lists the free `xcode-27` preview at 3 ARM64 CPUs, 7 GB RAM and 14 GB storage. A recent Serein job reported approximately 38 GiB free; that observation is not a guaranteed allocation. No paid runner or user-machine installation is permitted.

[WebKit's build instructions](https://webkit.org/building-webkit/) use `build-webkit` or the Xcode workspace. A reproducible custom-engine experiment must pin source and Xcode, log selected dependencies, measure checkout/build disk and process memory, bound concurrency and elapsed time, and stop before exhausting the runner. A source inventory cannot justify committing to distribution of a custom engine. No engine build has been launched or claimed feasible here.

## Conditions before adopting a custom engine

1. Identify a concrete required semantic gap that cannot be satisfied through a public host adapter; implement a minimal engine patch and a regression fixture.
2. Establish a bounded standard-runner build plan with measured peak disk/RAM, elapsed time, deterministic dependencies and a reproducible clean build. Do not remove unrelated runner tools or disable platform protections to make it fit.
3. Verify framework/helper loading, hardened-runtime signing and actual desktop execution on macOS 27. Keep system-engine and patched-engine evidence distinct.
4. Package every required framework/helper with license notices and inspect architecture, deployment targets and dependency paths. Apple signing/notarization credentials remain unavailable; ad-hoc packaging must be disclosed.
5. Pin security updates to reviewed upstream changes, maintain a small patch queue, rebuild and rerun conformance before each release, and publish exact source/build provenance. An unmaintainable engine fork is not production-ready.

These conditions are unresolved. They preserve the WebKit requirement while avoiding an unsupported promise that a full engine build or universal compatibility fits the available resources.
