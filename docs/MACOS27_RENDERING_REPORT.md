# Prepared upstream report: macOS 27 standard runner WebKit desktop rendering

This is a reviewable report draft, not an issue that has been posted. Posting to another project's issue tracker requires explicit messaging authorization. Full browser implementation continues independently.

**Suggested repository:** `actions/runner-images`

**Suggested title:** `[xcode-27] WKWebView and Safari load DOM but render blank desktop content with IOSurface errors`

## Environment

Standard GitHub-hosted `xcode-27` ARM64 runner, public repository. macOS 27.0 build `26A428`; latest reproduced with Xcode 27.1 build `27A9269` (the original standalone probe used Xcode 27 build `27A266a`); Swift 6.4 (`swiftlang-6.4.0.34.1`); SDK and minimum target 27.0. No custom runner, paid runner, private WebKit settings, sandbox/SIP changes, or nested virtualization.

## Reproduction and public evidence

- [Standalone public-framework probe workflow](https://github.com/super-original/serein-browser/blob/continuation/rendering-and-session-safety/.github/workflows/platform-probe.yml) compiles and launches [PlatformProbe.swift](https://github.com/super-original/serein-browser/blob/continuation/rendering-and-session-safety/script/PlatformProbe.swift). It captures AppKit/WKWebView and separately launches Apple-signed system Safari against a local fixture.
- [Probe run 36705841148](https://github.com/super-original/serein-browser/actions/runs/36705841148) includes actual OS/toolchain output, screenshots, Safari title, public IOSurface allocation results, captured SDK headers and WebKit errors.
- [Application run 36707859265](https://github.com/super-original/serein-browser/actions/runs/36707859265) independently builds and runs Serein and a plain AppKit WKWebView. The actual app reports loaded document text/title/geometry; screenshot-based rendering gate reports zero dark fixture-content pixels. Subsequent fresh runs reproduce the desktop failure.
- [Raw inspected evidence](https://github.com/super-original/serein-browser/tree/continuation/rendering-and-session-safety/docs/evidence/2026-09-30) includes Serein and Safari desktop captures. [Pinned Zen reference run](https://github.com/super-original/serein-browser/actions/runs/36705707876) renders the same local fixture on the same runner label.

To reproduce in the public repository, dispatch `macOS 27 platform evidence` on `continuation/rendering-and-session-safety`. `script/platform_probe.sh` explicitly selects `/Applications/Xcode_27.0.app`, compiles with `arm64-apple-macos27.0`, launches the probe as an app, captures the real desktop, then launches Safari with the deterministic HTTP fixture. No Apple account, website credentials, or external browsing state is required.

## Expected and observed

Expected: loaded HTML text/content appears inside the actual desktop WKWebView and Safari window.

Observed: native AppKit/SwiftUI chrome renders; DOM execution and navigation finish; WKWebView internal snapshots contain fixture content; desktop content is blank in Serein, a plain AppKit WKWebView and system Safari. `screencapture` and ScreenCaptureKit agree. WebKit emits repeated `IOSurface creation failed` errors. Public in-process IOSurfaceCreate allocations at representative dimensions succeed. An unhardened separately compiled probe also fails to show WebKit content. Gecko-based Zen renders the fixture.

These controls do not establish the root cause, prove all machines are affected, or prove that the runner image alone is responsible. They narrow investigation beyond the browser's SwiftUI view hierarchy, hardened signing, HTML fixture and one screenshot API. The failing desktop gate remains failing; internal snapshots are not used as a substitute.

## Request

Is there a supported standard free-runner image update or public-framework workaround for system WebKit desktop surface composition on this macOS 27 preview? Additional public diagnostics can be added to the standalone probe. The project must retain macOS 27 runtime validation and WebKit without private flags, security weakening, paid runners or using the user's computer.

## Free-runner recheck, September 30 continuation

The official [runner catalog](https://github.com/actions/runner-images/blob/main/README.md) and [image inventory](https://github.com/actions/runner-images/blob/main/images/macos/xcode-27-arm64-Readme.md) still list image `20260921.0210.1`, macOS 27.0 `26A428`, Safari 27.0 `22625.1.29.11.27`. The free standard label is `xcode-27`; the listed `xcode-27-xlarge` is outside this task's free-standard constraint. Xcode 27.2 beta is available on the same runtime; choosing another compiler is not a second macOS runtime or proof of a compositor fix. No supported second free macOS 27 runtime was identified. The `a1dea358` run's captures 35 and 38 were retrieved and inspected again: ordinary content blank, GPU-primed fullscreen black.


## October 1: newer runner image and independent newer WebKit

[Diagnostic run 36799509066](https://github.com/super-original/serein-browser/actions/runs/36799509066) at `25a1a70a89c8d62c864779e859e786b47a33774e` used standard image **20260928.0222.1**, still macOS 27.0 **26A428**. This supersedes the September 21 image inventory observation above. [Diagnostic artifact](https://github.com/super-original/serein-browser/actions/runs/36799509066/artifacts/11134503954) contains the installer assessment, versions, per-browser automation and glyph results, and original desktop captures.

Apple-signed **Safari Technology Preview 253**, build **22626.1.8.19.2**, was installed only on the ephemeral runner from Apple's pinned macOS 27 DMG. Its SHA-256 was `dbfcc270a845b9a7ac74b13b762808ef19a5652eabadc5b7719291754dc01c8e`; package assessment and installed-app signature verification passed. No production engine substitution or security setting change was made. See [Apple's release notes](https://developer.apple.com/documentation/safari-technology-preview-release-notes/stp-release-253) and [workflow](../.github/workflows/stp-probe.yml).

Both system Safari and Technology Preview reached the deterministic **Field Notes** document title, had no UserNotificationCenter window, and failed their desktop-content glyph check. **Both original screenshots were downloaded and visually inspected:** native controls and the scrollbar appear, while the website body is entirely white. Earlier captures with a local-network consent dialog were rejected as invalid evidence; this run is unobscured. The preview's newer WebKit therefore does not resolve this observed runner failure. It is an independent witness and does not replace Serein's own rendering gate or prove the underlying cause.
