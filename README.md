# Serein

An original native Swift/WebKit browser for **macOS 27.0 or later**, taking Zen 1.22.2b as its layout and interaction reference. Apple Silicon builds run entirely on standard GitHub-hosted `xcode-27` runners. No Xcode, SDK, engine build, or build cache is needed to use the packaged application.

**Development work in progress. This is not a completed production browser. Full Chrome, Firefox, and Safari extension compatibility has not been achieved.** Successful compilation is not evidence of complete behavior or visual fidelity.

- [Build, runtime tests, and downloadable artifacts](https://github.com/super-original/serein-browser/actions/workflows/build.yml)
- [Pinned Zen reference captures](https://github.com/super-original/serein-browser/actions/workflows/zen-reference.yml)
- [macOS 27 SDK and graphical-runtime evidence](https://github.com/super-original/serein-browser/actions/workflows/platform-probe.yml)
- [Research and API decisions](docs/RESEARCH.md)
- [Architecture and security boundaries](docs/ARCHITECTURE.md)
- [Zen reference and parity](docs/ZEN_PARITY.md)
- [Extension compatibility](docs/EXTENSIONS.md)
- [Evidence, defects, and verification limits](docs/VERIFICATION.md)

## Download and install

Open a build run and download the `Serein-macOS27-arm64` artifact. Extract the artifact ZIP, then `Serein-macOS27-arm64.zip`. Drag `Serein.app` to Applications. Requires an Apple Silicon Mac running macOS 27.0 or later. Intel builds are not supplied or tested.

The application is **ad-hoc signed, with hardened runtime enabled; it is not Developer ID signed or notarized**. Gatekeeper may block first launch. Review the source and build first; if you choose to trust this development build, use macOS System Settings → Privacy & Security → Open Anyway after attempting to open it. Do not disable Gatekeeper globally. No signing identity, Apple Developer account, or notarization credentials have been supplied to this project. The final CI evidence records `codesign` verification and Mach-O minimum/SDK versions.

Artifacts expire after 14 days. Evidence artifacts expire after 7 days. The workflow can be rerun from its Actions page. A permanent signed release and automatic application updates are not implemented.

## Build without installing tools on your Mac

Use the Actions workflow. Its clean checkout runs `script/build.sh` and `script/verify_runtime.sh`, and uploads the application and diagnostic evidence. Public-repository standard GitHub-hosted runners are used, with read-only repository token permissions and no paid services. No engine is compiled and no build cache is retained.

For a contributor who already has Xcode 27 on a separate development machine, the same scripts are the build contract. `Package.swift`, `Info.plist`, compiler environment, and Mach-O assertions all require macOS 27.0. This is not a request to install those tools on the user's Mac.

## Basic controls

⌘L addresses/searches; ⌘T creates a tab; ⌘W closes it; ⇧⌘T reopens it; ⌘N opens a window; ⇧⌘N opens a private window; ⌘F finds text. ⇧⌘S toggles the expanded sidebar; ⌥⌘C toggles compact mode; ⌥⌘S splits with another tab. Tabs have native context menus for pinning, essentials, duplication, movement, unloading, and closing. Workspace controls are at the sidebar's bottom.

Serein has original branding and source code. Zen's name and reference captures identify the comparison target; no affiliation or endorsement is claimed. See [licenses](docs/LICENSES.md).
