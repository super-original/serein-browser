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

Use the Actions workflow. Its clean checkout runs `script/build.sh` and `script/verify_runtime.sh`, and uploads the application and diagnostic evidence. Public-repository standard GitHub-hosted runners are used, with read-only repository token permissions and no paid services. The application uses system WebKit. A separate bounded, unmodified WebKit build experiment measures custom-engine feasibility; it does not replace the shipped engine. A bounded compiler cache stays within the repository's free GitHub cache allowance; no cache is installed on your Mac.

For a contributor who already has Xcode 27 on a separate development machine, the same scripts are the build contract. `Package.swift`, `Info.plist`, compiler environment, and Mach-O assertions all require macOS 27.0. This is not a request to install those tools on the user's Mac.

## Basic controls

⌘L addresses/searches; ⌘T creates a tab; ⌘W closes it; ⇧⌘T reopens it; ⌘N opens a window; ⇧⌘N opens a private window; ⌘F finds text. ⇧⌘S toggles the expanded sidebar; ⌥⌘C toggles compact mode; ⌥⌘S splits with another tab. Tabs have native context menus for pinning, essentials, duplication, movement, unloading, and closing. Workspace controls are at the sidebar's bottom. Command-click toggles tab selection; Shift-click selects a range. The tab context menu can pin, unpin, move to a workspace, or close selected tabs.

Choose DuckDuckGo, Google, or Bing in Settings → Search engine. DuckDuckGo is the default.

Settings → Unload idle regular tabs is Off by default. Optional 15/30/60-minute unloading preserves in-memory navigation history and zoom, but other page state may be lost. Visible, private, pinned, edited and media pages are kept; active downloads pause unloading. Settings → Remember Back and Forward history between launches is a separate opt-in choice. It saves additional page/form state for normal web tabs; private tabs and currently detected edits are excluded. After an OS or WebKit update, tabs reopen at their saved URL instead. See the verification document for tested limits.

Tools → Save Page Screenshot… saves the selected page's visible area as PNG after you choose a destination. Private-window exports also persist on disk when saved. Full-page and region capture are not implemented. The image comes from WebKit's content snapshot API and is separate from desktop screenshot evidence.

In the address field, Down/Up select local history or bookmark suggestions, Return opens the selection, and Escape dismisses suggestions while retaining the typed query.

Downloads can be searched by filename or source and filtered by status. Clear All Finished removes finished records regardless of the current search, while keeping saved files. Downloads show progress and support pause/resume when WebKit supplies resume data. Normal download history and available pause/failure resume data survive relaunch. Active transfers without saved resume data become interrupted; server or partial-file changes can prevent resumption. Private download records belong to their originating private window and disappear when it closes; downloaded files remain on disk.

Camera, microphone and location choices are available under Browser Menu → Settings → Site Permissions. Choices are scoped to the exact requesting and top-level sites; private-window choices are discarded with that window. Settings changes apply to future requests; reload a page to end an existing grant.

Serein has original branding and source code. Zen's name and reference captures identify the comparison target; no affiliation or endorsement is claimed. See [licenses](docs/LICENSES.md).

Select two to four tabs with Command-click or Shift-click, then use **Split Selected Tabs** in a selected tab’s context menu. This creates a grid; **Exit Split View** returns to one page. Incremental Zen split layout preservation is still incomplete.

## Native applications used by extensions

Experimental native messaging is available for signed CRX3 packages. Install the native application separately, then open Browser Menu → Extensions → **Register Native Application…** for that extension. Select the application's Chrome-format JSON host manifest and review the executable path before choosing Allow. The manifest must explicitly allow the extension's verified Chrome identity. Registration does not grant a missing extension permission. Use the host's menu → **Revoke Access** to stop its connections and remove access. Disabling or removing the extension stops its native connections.

Firefox host registrations, unsigned package identities, automatic discovery of other browsers' registrations and Safari App Extensions are not supported. See the [compatibility matrix](docs/EXTENSIONS.md) for protocol/resource limits and actual verification status. Full extension compatibility remains unfinished.

## Tab folders

Use File → New Folder, or a tab's context menu → New Folder with Tab. Folders pin their contents and belong to one workspace. Drag a tab onto a folder to move it inside; drag a folder onto another to nest it, up to five levels. Collapsing keeps the active tab visible. Folder menus offer rename, new subfolder, ordering, workspace moves, Unpack Folder (keep pages) and Delete Folder (confirm closing its pages). Live folders, sharing and custom folder icons remain unfinished; current verification is recorded in the [parity checklist](docs/ZEN_PARITY.md).

Safari Web Extension `.appex` bundles have an installation path under development. Native Safari App Extensions, Safari native handlers, and automatic App Store acquisition remain unsupported; see [the compatibility matrix](docs/EXTENSIONS.md) for verification status.
