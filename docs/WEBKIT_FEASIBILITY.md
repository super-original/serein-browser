# Compatibility implementation and engine feasibility

Full extension compatibility remains the requirement. A rejected package is evidence of a missing capability, not proof that the capability cannot be implemented.

## Public system-engine route first

Browser-owned state (downloads, history, bookmarks, tab groups and sessions) can be implemented in Swift. The unresolved part is exposing the exact extension namespaces, permission semantics and events in every extension execution context, including service workers. Public `WKUserScript` injection alone does not establish worker API support.

An isolated MV2/MV3 experiment attempts to test `WKWebExtensionControllerDelegate`'s public native-message reply callback. It returns only a constant response, bound to a context identity, explicit `nativeMessaging` grant and one registered application/operation. It tests default denial and rejection of an unregistered application. At that early checkpoint, production installation still rejected native messaging; the later verified CRX3-only native-host registration path is now implemented, with explicit consent and scoped executable identity (see EXTENSIONS.md). Initial combined runs terminated during bundled-fixture loading. A separate process, copied fixture directory, complete manifest metadata and registered tab/window resolved the probe setup. Run 36719132526 at `f20b79b` passed all eight MV2/MV3 transport/denial checks. This establishes only the constant-reply transport, not an API adapter. The SDK requires distinct configurations when multiple controllers coexist. A successful experiment would justify a narrowly scoped compatibility-adapter investigation, not arbitrary native-process access or a claim of implemented downloads/history APIs. Required follow-up: validate namespace installation in worker/page/isolated content worlds; host-side capability checks; argument validation; exact errors/events; revocation and private access; original-package integrity and transparent transformation policy.

Blocking request interception, Firefox DNS, service-worker lifetime and offscreen rendering need separate engine-level investigation. A native state adapter alone cannot reproduce them. SafariServices native handlers and legacy Safari formats need separate hosting/translation research; a WebKit rebuild does not automatically solve those formats.

## Measured source inventory, not a build-size claim

The [recorded inventory](evidence/2026-09-30/webkit-source-inventory.json) pins WebKit `131cc0a7111b3a8c4038989d7bd5cee49c1ad7f7`. Selected build-related Git trees contain 1,332,468,145 blob bytes (about 1.24 GiB). Truncated GitHub tree responses were expanded recursively. Reproduce with `python3 script/webkit_source_inventory.py --output inventory.json` and authenticated read-only `gh` access. This excludes Git storage, generated products, dependencies and other directories; it measures neither peak disk/RAM nor build time.

[GitHub's standard public-runner table](https://docs.github.com/en/actions/reference/runners/github-hosted-runners) lists the free `xcode-27` preview at 3 ARM64 CPUs, 7 GB RAM and 14 GB storage. A recent Serein job reported approximately 38 GiB free; that observation is not a guaranteed allocation. No paid runner or user-machine installation is permitted.

[WebKit's build instructions](https://webkit.org/building-webkit/) use `build-webkit` or the Xcode workspace. A reproducible custom-engine experiment must pin source and Xcode, log selected dependencies, measure checkout/build disk and process memory, bound concurrency and elapsed time, and stop before exhausting the runner. A source inventory cannot justify committing to distribution of a custom engine. The first bounded engine attempt is recorded below; no completed build is claimed feasible.

## Conditions before adopting a custom engine

1. Identify a concrete required semantic gap that cannot be satisfied through a public host adapter; implement a minimal engine patch and a regression fixture.
2. Establish a bounded standard-runner build plan with measured peak disk/RAM, elapsed time, deterministic dependencies and a reproducible clean build. Do not remove unrelated runner tools or disable platform protections to make it fit.
3. Verify framework/helper loading, hardened-runtime signing and actual desktop execution on macOS 27. Keep system-engine and patched-engine evidence distinct.
4. Package every required framework/helper with license notices and inspect architecture, deployment targets and dependency paths. Apple signing/notarization credentials remain unavailable; ad-hoc packaging must be disclosed.
5. Pin security updates to reviewed upstream changes, maintain a small patch queue, rebuild and rerun conformance before each release, and publish exact source/build provenance. An unmaintainable engine fork is not production-ready.

These conditions are unresolved. They preserve the WebKit requirement while avoiding an unsupported promise that a full engine build or universal compatibility fits the available resources.

A follow-up isolated probe attempts to define the absent `browser.downloads` namespace in each MV2 background page and MV3 service worker, with a single clearly diagnostic method forwarding the same constant native-message reply. It records the actual execution-world type and namespace definition error. No downloads method, permission, native host or data access is implemented by this experiment. Production installation gates are unchanged. Run [36723768551](https://github.com/super-original/serein-browser/actions/runs/36723768551), `b854f84`, passed all 12 isolated checks: both namespace definitions worked, the actual MV3 ServiceWorkerGlobalScope and MV2 nonworker world were confirmed, pre-grant calls remained denied and the unknown application remained rejected. This removes one transport/namespace uncertainty; implementing complete host API semantics, transparent package transformation and independent permissions remains feasible work, not a platform impossibility.

## Verified host download prerequisites, October 1

The native model now retains response metadata and durable JavaScript-safe numeric identifiers. At `b236aa8`, six store identity checks, 21 separate-process download checks and four native search/privacy checks pass. The production extension namespace remains absent. A compatibility layer still needs a separate original-manifest capability ledger; context-bound authorization on every request; complete query/error/control/event semantics; worker/page startup injection that preserves original entry points; and explicit original-versus-transformed package provenance. Transport success does not justify granting arbitrary native messaging or silently removing requested downloads permissions. Private extension access remains disabled.

## Bounded public-SDK build experiment

The retained host-revocation/cookie-event defects and missing extension event/API behavior justify measuring an engine route before relying on it. This experiment builds **unmodified** WebKit `131cc0a7111b3a8c4038989d7bd5cee49c1ad7f7`; it neither adopts a custom engine nor claims that source changes will repair the runner's desktop compositor.

Reproduction: `.github/workflows/webkit-build-probe.yml` runs `python3 script/webkit_build_experiment.py` on standard free `xcode-27`. Xcode 27.1 `27A9269`, SDK 27.0, ARM64 and minimum deployment 27.0 are asserted. The [pinned public build script](https://github.com/WebKit/WebKit/blob/131cc0a7111b3a8c4038989d7bd5cee49c1ad7f7/Tools/Scripts/build-webkit) forwards Xcode arguments; [WebKit's build documentation](https://webkit.org/building-webkit/) specifies this route. `--only=Everything up to WebKit` selects the upstream framework/dependency/helper scheme rather than the full tools suite; no runtime feature-disabling switches are used. The first attempt used `--only-webkit`, which actually omits prerequisites on a clean checkout; its failure is retained below.

The shallow, filtered checkout includes Source, Tools, Configurations, resources, metadata, WebKitLibraries, WebKit.xcworkspace and root files. Large unrelated web-test corpora are omitted; any missing required build resource must be reported and corrected, not hidden. The exact source hash and initially clean source status are recorded. Dependencies must be supplied by that public source and the installed runner toolchain. The initial attempts used only the preinstalled toolchain. The later Metal prerequisite stage is documented below; no security-setting change, paid runner, shared-cache purge or user-machine operation is performed.

The first measurement allows ten minutes for fetch, fifteen for checkout and seventy-five for the release build, with two Xcode jobs and a 110-minute workflow ceiling. It stops below an 8 GiB disk reserve, above 5 GiB sampled descendant RSS, or below 8% system free-memory percentage from `memory_pressure -Q`. These are experiment budgets, not estimates that a full engine will fit. The supervisor signals only its own newly created process group. Five tests cover process attribution, independent resource/time stops, owned-child termination and successful/final output capture. The first macOS run caught lost final pipe bytes during shutdown before any engine build; the supervisor now retries a read after its stop wakeup, with a deterministic regression case. All five pass locally and on macOS in the subsequent recorded attempts.

Evidence includes actual toolchain, per-stage elapsed time, sampled descendant RSS, free disk, global memory pressure, bounded initial/final logs and approximate checkout/build allocation from `du`. XPC services and short-lived peaks can be omitted from descendant RSS; global pressure is a separate safeguard, not exact attribution. RSS can double-count shared pages. Source-size inventory remains distinct from measured resource use. No source tree, engine binary or large build cache is uploaded by this experiment.

Acceptance for this stage is an actual framework-producing public-SDK build within the measured limits, with ARM64, minimum macOS 27.0 and SDK 27.0 verified from its Mach-O binary, or a precise reproducible failure/resource boundary. A timeout, sparse-checkout omission, toolchain mismatch or missing dependency does **not** prove that all custom WebKit builds are impossible. A passing compile still requires a minimal regression-tested engine patch, hardened signing/helper/framework loading, macOS 27 execution, complete license/redistribution review, packaging and a maintainable security-update process before any adoption. The planned update discipline is a pinned upstream revision plus a small reviewed patch queue, rebuilds on upstream security changes, and retained permission/lifecycle/real-package conformance gates; none of that operational evidence exists yet.

The production install/update path now records original manifest bytes and hashes, installed manifest hash, and required/optional API/host declarations outside extension resources. Preparation must preserve those declarations, and loading validates the recorded installed manifest. Existing installations without provenance remain explicitly legacy; no original hash is invented. A Requested Access sheet separates original requests from current grants. This foundation does not grant host capabilities, transform background entry points or admit any of the seven rejected packages. At `fc53c18`, all three core tests and five runtime ledger/access-review checks pass; the native sheet was retrieved and inspected.

### First actual attempt and corrected scheme

At `d793399`, [run 36843227975](https://github.com/super-original/serein-browser/actions/runs/36843227975) passed all five supervisor tests on macOS 27.0 / Xcode 27.1. The exact shallow checkout took 77.28 seconds and occupied approximately 1.87 GiB including Git data; its sampled descendant RSS peaked at 594.73 MiB. The build ran for 28.79 seconds, returned Xcode exit 65, and peaked at 952.27 MiB sampled descendant RSS with 36.30 GiB free disk remaining. No resource stop occurred and no framework was produced. [Original resource/log artifact](https://github.com/super-original/serein-browser/actions/runs/36843227975/artifacts/11152815895).

The `WebKit` scheme built only five local project targets and failed to find the generated WTF `generate-unified-source-bundles.py` prerequisite. This is a scheme-selection error, not evidence that a full engine exceeds the runner. The corrected command selects the pinned upstream [Everything up to WebKit scheme](https://github.com/WebKit/WebKit/blob/131cc0a7111b3a8c4038989d7bd5cee49c1ad7f7/WebKit.xcworkspace/xcshareddata/xcschemes/Everything%20up%20to%20WebKit.xcscheme), which explicitly includes bmalloc, WTF, JavaScriptCore, ANGLE, WebGPU, WebCore, WebInspectorUI, WebKitLegacy and WebKit helpers. The same resource limits remain in force; corrected build results are pending.

### Full dependency scheme attempt, October 1

At `fc53c18`, [run 36844654036](https://github.com/super-original/serein-browser/actions/runs/36844654036) compiled the full dependency scheme for 552.35 seconds before Xcode exited 65: `cannot execute tool 'metal' due to missing Metal Toolchain; use: xcodebuild -downloadComponent MetalToolchain`. No resource guard fired. Sampled descendant peak RSS was 2,704,048,128 bytes, with minimum free disk 36,714,033,152 bytes. This measures partial compilation only; no complete framework was produced. [Raw evidence](https://github.com/super-original/serein-browser/actions/runs/36844654036/artifacts/11153397165), retrieved and SHA-256 verified (`6d49156bc0ac8a86dac949eb3e12cdc1d47695b71b4084bc53bcc5dc70271d32`).

The next attempt runs the exact public component-download command recommended by Apple's compiler, only on the disposable standard runner, with a ten-minute budget and the existing disk/memory guards. It records the resulting Metal version before compiling. The workflow budget is 120 minutes to accommodate the additional stage; the engine compilation budget remains 75 minutes. No features are disabled, source patches applied, or engine adopted by Serein.

### Content-script phase investigation

The pinned [manifest parser](https://github.com/WebKit/WebKit/blob/131cc0a7111b3a8c4038989d7bd5cee49c1ad7f7/Source/WebKit/UIProcess/Extensions/WebExtension.cpp) distinguishes MAIN and isolated worlds. The [context's injection-time mapping](https://github.com/WebKit/WebKit/blob/131cc0a7111b3a8c4038989d7bd5cee49c1ad7f7/Source/WebKit/UIProcess/Extensions/WebExtensionContext.cpp#L1275) maps idle to the end phase and explicitly leaves idle scheduling unfinished. This is upstream source evidence, not proof of the installed system binary's behavior.

JSON Formatter's original idle MAIN script exits if the isolated end script has not yet created its raw-content DOM. Its missing global in `5959e2c` could therefore involve ordering rather than absent MAIN-world support. An original controlled end-marker/idle-reader fixture is being added to separate execution, world placement and ordering. No third-party executable source is rewritten, no engine patch applied, and no full idle-semantics claim made.

At `6c156fa`, the controlled MAIN script executes in the page world and sees the isolated end marker; all three checks pass. This does not demonstrate an ordering defect in the real Formatter scenario, which still lacks its global. Bounded original-options storage readback succeeds. A separate Gecko scenario is prepared using the same pinned source build, unchanged executable resources and only a declared Gecko installation ID added to the manifest. Its actual-page-global result and screenshot must be inspected before drawing a cross-engine conclusion.

### Metal-enabled build reached the experiment timeout

At `c366ef2`, [run 36846671516](https://github.com/super-original/serein-browser/actions/runs/36846671516) installed Metal successfully and compiled for 4,501.27 seconds before the 75-minute guard stopped it in WebCore. No full framework was produced. Peak sampled descendant RSS was 3.562 GiB, minimum free disk 12.026 GiB, and the owned source/product tree occupied approximately 15.427 GiB, excluding external compiler caches. [Published stage/toolchain summaries and limitations](evidence/2026-10-01/webkit-build-c366ef2/README.md). The artifact was downloaded and its SHA-256 verified.

The next bounded experiment allows 180 minutes of compilation and a 225-minute workflow, retaining the same source, two jobs, 8 GiB disk reserve, 5 GiB descendant-RSS and 8% global-free-memory guards. [GitHub permits six-hour hosted jobs](https://docs.github.com/en/actions/reference/limits); standard public runners remain free. Apple's [documented Xcode build settings](https://developer.apple.com/documentation/xcode/build-settings-reference) provide `GCC_GENERATE_DEBUGGING_SYMBOLS=NO`, `CLANG_ENABLE_MODULE_DEBUGGING=NO` and `DEBUG_INFORMATION_FORMAT=dwarf`. These avoid full compiler/module debug information and dSYM output for this storage-feasibility experiment; they do not disable engine runtime features. Full source-level symbolication would be unavailable and must be addressed before production distribution. This tests a resource hypothesis; no size or time improvement is claimed in advance.

The original build log contains upstream engineering-build and lower-format-reader-signing flags. They are not production security approval: no compiled engine is loaded by Serein, and adoption still requires a separate hardening/helper/entitlement audit. The current production browser continues to use system WebKit.

The subsequent exact `719f0cf` run reproduces the controlled phase-order failure: MAIN execution and global visibility succeed, but its idle-time read reports the end marker missing. Earlier runs read it successfully. This strengthens the case for investigating collapsed end/idle injection phases; it does not prove that a particular engine patch fixes the real extension. A final end-marker readback is added next.

### Complete framework achieved; signing and production configuration remain blocked

The exact `6b49ccd` [run 36856490466](https://github.com/super-original/serein-browser/actions/runs/36856490466)
completed in 85.32 minutes with an arm64 / minos 27.0 / SDK 27.0 framework. Peak sampled
descendant RSS was 4.509 GiB and minimum free disk 19.720 GiB. The owned tree occupied
approximately 6.530 GiB. [Retrieved measurements, metadata and inspected chart](evidence/2026-10-01/webkit-build-6b49ccd/README.md).
This resolves the narrow clean-build capacity question for this pinned source and symbol
configuration on the free runner; it does not establish production readiness.

The framework's deep/strict signature check failed on a sealed resource. The source audit
also confirms that upstream Release uses engineering/development configuration and disables
library validation. No resulting binary was loaded, re-signed or adopted. A follow-up bounded
build collects read-only verbose signatures, entitlements, dependency paths, hashes and
minimum-OS metadata for nested framework/helper products, retaining failures explicitly.
Its audit has local regression coverage for failed signatures, escaping symlinks and timeouts.

Before a custom engine could ship, all of these gates remain necessary: explain and repair
the seal failure in the build/package process; establish supported hardened helper launch
and sandbox/library-validation policies without private entitlements or bypasses; preserve
public API boundaries; run the same actual desktop and extension-boundary suite; audit all
redistributed licenses and symbols; package/sign/notarize the complete dependency tree; and
establish a repeatable security-update process. A clean 85-minute build makes one candidate
plus native verification plausible within a six-hour job, but future security patches need
fresh measurements. Pin revisions, review upstream security fixes and produce a new exact-head
artifact for every update; never silently keep an unsupported engine revision after known
security fixes. No production update SLA or owner approval is claimed here.
