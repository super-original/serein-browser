# Zen baseline and parity

Reference: **Zen 1.22.2b**, published 2026-09-16, official universal macOS DMG. SHA-256 `2332673353551bfe4607aa6edd3c3ee3149652651a7698acabad935612c93943`.

The authoritative hash in `script/zen_reference.sh` is checked before mounting the image. References use a fresh profile, built-in theme, no mods, single-toolbar mode, expanded sidebar initially, 1000×700 requested outer rectangle. The runner constrained the resulting window to **1000×677 points**, at **1× scale**, on a **1024×768** desktop. The fixture pages are served from loopback. Light/dark browser chrome is controlled independently of the page's light content preference.

Sources: [official release](https://github.com/zen-browser/desktop/releases/tag/1.22.2b), [website](https://zen-browser.app/), [manual](https://docs.zen-browser.app/user-manual), [pinned source](https://github.com/zen-browser/desktop/tree/1.22.2b). The manual warns that some content may be outdated; the running pinned build and its source take precedence.

## Captures

The reference workflow launches the actual downloaded Zen binary with geckodriver on macOS 27. It drives the browser's real state, then uses the runner's desktop capture. No browser mockup is substituted. `manifest.json` records measured DOM geometry for each capture. The application is neither modified nor redistributed.

| Reference | State |
|---|---|
| 01 | Light full window, expanded sidebar |
| 02 | Dark full window, expanded sidebar |
| 03 | Essential tab and ordinary tab |
| 04 | Essential, pinned, active/inactive normal tabs |
| 05 | Address editing/focus |
| 06 | Actual tab context menu |
| 07 | Research workspace |
| 08 | Switch back to original workspace |
| 09 | Two-pane split with different fixture pages |
| 10 | Compact sidebar hidden |
| 11 | Compact sidebar revealed over content |
| 12 | Collapsed vertical tabs with top address toolbar |
| 13 | Native running Zen preferences page |
| 14 | Navigation error/restricted address page |
| 15 | Active and pinned tab multiselection |

Early captures were invalid: a network-consent dialog obscured them, and initial split/compact scenarios did not reach their intended state. These were inspected and corrected, not counted as successful references. The corrected split and compact captures are in [run 35241652810](https://github.com/super-original/serein-browser/actions/runs/35241652810). State names alone are never a visual assertion.

## Geometry and deliberate differences

| Element | Pinned reference | Serein decision |
|---|---|---|
| Expanded sidebar | 230 pt measured toolbox | Default 230; user-resizable within 180–500 |
| Ordinary tab layout box | 40 pt high, 224 pt wide including spacing | 36 pt control + 4 pt inter-row gap; native selectable button |
| Tab horizontal inset | Approximately 8 pt | 8 pt sidebar padding, 10 pt inner label padding |
| Content left edge | About 246 px including window origin | 230 pt sidebar + 6 pt separation |
| Content inset | About 8 pt top/right/bottom | 8 pt |
| Tab typography | About 13 pt, stronger selected state | System 13 pt, semibold selection |
| Essential cells | Compact icon-only region above workspace | Shared across workspaces; original SF Symbol until favicon support |
| Navigation header | Traffic lights, sidebar button, back, forward, reload | Same order; native system traffic-light geometry retained |
| Tab shape | Rounded selected tab | 8 pt selected-tab corner radius |
| Compact transitions | Hover keep duration 150 ms, toolbar hide 1,000 ms in source | Sidebar hover hide 150 ms; toolbar-only/both variants not implemented |
| Materials | Zen's default Gecko theme | Native macOS 27 Liquid Glass; different tint/contrast is intentional, not claimed as pixel matching |

SF Symbol fallback icons do not reproduce site favicons. Native address field, sheets and menus deliberately follow macOS 27 treatment. Geometry discrepancies, missing Zen interactions and clipping are defects, not automatically justified as material adaptation.

## Parity checklist

Status: **I** implemented with some exercised paths; **P** partial; **U** unimplemented/unverified. The verification document limits what has actually been tested.

| Feature | Status | Scope / gap |
|---|---|---|
| Back/forward, reload/stop, URL/search | I | WKWebView; local-history/bookmark suggestions only |
| Create/close/reopen/duplicate tabs | I | Unsaved form-input warning; broader app state detection incomplete |
| Reorder | P | Typed same-process tab/folder payloads; cross-window normal-tab dragging and folder drops implemented; actual cross-window pointer and all transfer/privacy checks pass at `21091e9`; category changes, cross-window folder trees and drag-to-new-window remain absent |
| Pins and essentials | I | Essentials span workspaces; pins preserve reset URL |
| Multiple workspaces | P | Create, rename, remove, switch; no containers or per-workspace cookie stores |
| Expanded/collapsed sidebar | I | Visual inspection required across resizing and focus |
| Compact mode | P | Edge reveal/hide; Zen's complete toolbar variants absent |
| Split views | P | Explicit selected-tab grids up to four panes verified at `d4c80d1`; balanced native dividers and minimum-window bounds verified at `e32960d`; split-group tabs, incremental layout preservation and drag composition remain absent |
| Multiple windows / moving tabs | P | Normal live-tab transfer through menu and typed drop targets; isolated private transfer deliberately rejected |
| Persistent sessions | P | Tab/workspace/sidebar and ordinary frame restoration; full navigation-history restoration across launches remains absent |
| Bookmarks / history / find | I | Basic library, search, clear, find navigation |
| Downloads | P | Native save/cancel/reveal, durable normal history, progress and in-memory pause/resume; cross-launch resume passed the separate-process integrity/privacy gate at `29dabbf`; live ordinary downloads now pause on real Command-Q and resume after relaunch with full byte integrity at `c1e2498`; a live private transfer stays out of recovery files |
| Private browsing | I | Nonpersistent store per window; no saved private tabs/history; extensions excluded |
| File selection / JS dialogs | I | Native panels; broader UI automation pending |
| Site permissions / media | P | Exact-origin camera/microphone/location policies, Ask/Allow/Deny and reset; private policies are memory-only; physical media delivery and subframe cancellation coverage incomplete |
| Fullscreen | P | Native window/fullscreen WebKit preference; media runtime coverage incomplete |
| Loading / errors / process recovery | P | Actual attributed WebContent termination, native crash screen and AX Reload recovery pass at `d365cfc`; desktop website rendering remains blocked |
| Settings | P | Appearance, sidebar, search engine, external essential previews and website data clearing; advanced policies absent |
| Glance / link preview | P | Native Option-click overlay and parent/child lifecycle implemented; geometry, minimum bounds, actual Option-click/Escape/focus, live movement/split, consent, private isolation and reopened relationships pass at `7ef2e5f`; cycling/expansion now pass at `4449c7a`. Configurable external-host popup routing, restored-owner attachment, independent message-controller ownership and parent edit tracking pass at `c136b59`; its actual essential-preview screenshot was inspected. Nested previews and animation parity remain gaps. |
| Folders / live folders | P / U | Native nested pinned folders implemented; all 19 creation/persistence/unpack/deletion/conversion checks verified at `32b17e3`; live providers, sharing and icon selection remain absent |
| Tab multiselect | P | Command-click toggling, anchored Shift ranges and explicit bulk close; native state tests and desktop capture verified at `7ce1cad`; bulk pin/unpin and workspace moves verified at `e511f58` and later runs; full keyboard selection remains a gap |
| Tab groups | U | Not implemented |
| Containers / profiles / per-site isolation | U | Not implemented |
| Zen Mods / themes / gradient editor | U | Not implemented; native glass adaptation is separate |
| Sync / account / import wizard | U | Not implemented |
| Tab unloading | P | Manual with warning and document/selection revalidation; old-view release and in-memory back/current/forward/zoom restoration verified at `3209fee`, including extension resources. No automatic suspension or cross-launch history restoration |
| Keyboard customization | U | Fixed native shortcuts only |
| Picture-in-picture / screenshot tools | U | Not implemented as browser commands |
| Full extension compatibility | U | See detailed matrix; target remains unmet |

This checklist is intentionally not a claim of complete Zen parity.

## Refreshed baseline, September 30

[Run 36705707876](https://github.com/super-original/serein-browser/actions/runs/36705707876) reproduced all 14 captures with the same pinned Zen 1.22.2b binary and settings on macOS 27. All 14 screenshots were retrieved and visually inspected. Light/dark, essentials/pins, address focus, context menu, workspace labels, split panes, compact overlay/hide, collapsed toolbar, settings and restricted-port error states are visible. The context menu is taller than the available area and scrolls; it is not a full-menu inventory. Workspace captures retain the fixture page while changing workspace labels; they do not prove cookie/container isolation.

The measured sidebar remains 230 points and regular tab layout boxes 224×40. Full-window light captures match 1000×677 outer bounds and 1× scale. Serein's content starts at the same x≈246, but its bordered native address field is visually shorter than Zen's address surface. Essentials lack favicons and have different cell sizing; split-group tab representation and compact toolbar variants remain gaps. Zen shows a 2-point accent outline on the focused split pane; the continuation adopts that focus indicator using the native accent color. Native system traffic lights/materials intentionally differ. Serein's blank WebKit area remains a rendering defect/blocker, never a deliberate glass adaptation.

### Additional grid baseline under capture

The pinned [ZenViewSplitter source](https://github.com/zen-browser/desktop/blob/1.22.2b/src/zen/split-view/ZenViewSplitter.mjs) caps split groups at four tabs. Its `calculateLayoutTree` places two tabs side by side, three as two stacked left panes plus one full-height right pane, and four as two stacked columns. [Run 36752869953](https://github.com/super-original/serein-browser/actions/runs/36752869953) captures three panes and then adds a fourth; both screenshots were inspected. The fourth addition preserves the existing left stack and appends another full-height column, rather than rebuilding a two-by-two grid. A separate fresh four-pane grid capture is now requested. Serein's new explicit “Split Selected Tabs” builds the initial grid, pending runtime verification. Incrementally adding panes and retaining arbitrary prior divider trees remains unsupported; the existing “Split with Current Tab” still creates a new pair.

The fresh four-pane grid in [run 36753946618](https://github.com/super-original/serein-browser/actions/runs/36753946618) was retrieved and inspected. Relative to the window, its pane rectangles are (236,8,374.5,326), (236,343,374.5,326), (618.5,8,374.5,326), (618.5,343,374.5,326). Serein's first grid captures show the correct pane order and focus outline but uneven heights and narrow column spacing; these remain visual defects until the native-divider follow-up is inspected. WebKit page rendering remains blank.

At `e32960d`, the native divider follow-up passes balanced geometry and minimum-window tests. Retrieved/inspected screenshots confirm eight-point column gaps and 327/326-point rows. [Original-image comparison](evidence/2026-09-30/grid/README.md) records exact differences from Zen, including differing sidebar/focus state and blank Serein content. This is geometry evidence, not complete visual parity.

Glance research uses the pinned [manager](https://github.com/zen-browser/desktop/blob/1.22.2b/src/zen/glance/ZenGlanceManager.mjs) and [styles](https://github.com/zen-browser/desktop/blob/1.22.2b/src/zen/glance/zen-glance.css). Zen associates a hidden child tab with its owner, overlays the preview, and provides close, expand and split actions. A new real reference capture opens an existing tab through this manager; it does not claim to test modifier-click input. Serein implements this structure; verified behavior and remaining failures are listed below.


The [Glance reference run 36760541400](https://github.com/super-original/serein-browser/actions/runs/36760541400) succeeded and capture 19 was retrieved/inspected. At 1000×677 outer bounds, preview content is (311.6,8,604.8,661) relative to the window, and controls occupy (916.4,23,56,144). The [pinned preference](https://github.com/zen-browser/desktop/blob/1.22.2b/prefs/zen/glance.yaml) defaults activation to Alt (Option), overriding the actor's Ctrl fallback. Serein uses native glass buttons for close/expand/split, matching the 80%-width/full-height layout at reference size. At minimum width the preview narrows to retain a 56-point controls margin. These intentional native/adaptive choices do not establish visual parity; [Original reference/runtime screenshots](evidence/2026-09-30/glance/README.md) are inspected; blank page content remains a rendering defect.

Parent and preview remain separate native tabs sharing one session's website data. The preview is hidden from the ordinary sidebar list and represented by a parent-row badge. Expand/split reuse its live web view. Closing an owner includes preview edit consent; cross-window movement carries both live views. Private previews stay in their window's nonpersistent store. Unit/runtime scenarios are included, but their addition alone is not a passing result. No Zen code or assets were copied into this implementation.


At `71983bc`, actual Serein Glance screenshots were inspected: the preview rectangle is (312,8,604,661), within one pixel of Zen's 1× geometry; the minimum-window preview is (292,8,284,384), leaving controls inside the window. Native circular glass controls are visible and unclipped. Page surfaces remain blank due to the existing WebKit desktop-rendering failure. Six Glance interaction assertions fail and are being corrected; visual geometry alone is not feature completion.

At `7ef2e5f`, real Option-click, Escape, returned page-key delivery and reopened parent/preview relationships pass. Tab-cycling and dependent expansion setup still fail. The pinned manager makes external-host previews from pinned/app tabs a configurable preference enabled by the [shipped preference file](https://github.com/zen-browser/desktop/blob/1.22.2b/prefs/zen/glance.yaml), overriding the manager’s false fallback; the follow-up adds this choice for pinned/essential tabs and preserves WebKit's supplied popup configuration and original request. It intentionally limits previews to HTTP(S); local-file previews remain unsupported. Runtime verification is pending.

At `884d731`, expansion preserves the same live WKWebView and JavaScript state; both Control-Tab directions still fail. Their next fix handles native key-equivalent dispatch before WebKit.

The next native-interaction batch adds a persistent DuckDuckGo/Google/Bing search-engine picker (DuckDuckGo remains the existing default). Explicit URLs keep normal navigation. Escape handling now defers to WebKit while a preview is in element fullscreen; both ordinary-page and Glance fullscreen receive native-pointer/DOM/state checks. These changes are pending exact-head verification.

### Folder baseline under continuation

The pinned [folder manager](https://github.com/zen-browser/desktop/blob/1.22.2b/src/zen/folders/ZenFolders.mjs), [folder element](https://github.com/zen-browser/desktop/blob/1.22.2b/src/zen/folders/ZenFolder.mjs), [styles](https://github.com/zen-browser/desktop/blob/1.22.2b/src/zen/folders/zen-folders.css) and [creation test](https://github.com/zen-browser/desktop/blob/1.22.2b/src/zen/tests/folders/browser_folder_create.js) establish workspace-scoped pinned folders, nested groups, expanded creation, click-to-collapse, an internal empty tab and 14-point nested indentation. Deletion closes contents; unpacking retains tabs. Folder depth defaults to five in the manager. Native implementation must distinguish removal of the folder from destructive closure of its pages and retain document-bound consent. Live folders additionally use providers and remain a separate unimplemented capability.

The reference harness now requests four additional captures from the same unmodified 1.22.2b binary: expanded, collapsed, nested and context-menu states. Folder label/content geometry and parent/collapsed state are recorded. The results below record the retrieved captures and implemented native UI. No Zen source or icon assets are copied into the browser implementation.

The [folder reference run 36781892358](https://github.com/super-original/serein-browser/actions/runs/36781892358) succeeded. All four new original captures were retrieved and inspected: a 40-point label row, 14-point child indentation, retained active child when collapsed, nested folder and native context menu. The nested capture reports the parent DOM collapsed flag while showing its descendants after insertion; it is not evidence of a clean expanded transition.

The continuation implements native folder naming/renaming, selected-tab creation/pinning, nesting (maximum five levels), collapse retaining the active owner, drop-to-folder, explicit sibling ordering, workspace moves, unpacking and document-bound deletion consent. Optional session fields preserve older-session decoding; repair rejects orphan/cyclic/cross-workspace membership. Unpacking keeps live views; deletion closes captured documents only after fresh consent. Native SF Symbols replace Zen's custom SVG icons deliberately. The first implementation has no live providers, folder share/import, custom icons or drag insertion between arbitrary folder rows; no full folder parity is claimed. Twelve folder core tests and all 19 runtime folder checks pass at `b3e2899`, including actual AX collapse and live folder-to-workspace conversion. [Inspected comparison captures](evidence/2026-09-30/folders-and-safari/README.md) retain the blank-WebKit-content limitation and imperfect active-window matching. The behavior follows the pinned manager’s `convertFolderToSpace` action; no source is copied.

The first Serein folder scenario accidentally closed its global essential after switching to an empty workspace, because that essential remained selected. Its 44–46 captures therefore cannot establish vertically matched folder placement. The corrected setup retains an essential showing the same local fixture page. Zen’s recorded essential outer row is 50 points (44-point visual tile plus margins); Serein now uses a 44-point essential tile with its existing six vertical padding points. The appearance still needs fresh native capture; SF Symbol fallback and native material treatment remain deliberate differences.

The inspected `c0061e9` capture confirms the essential tile’s 44-point height but shows an unintended narrow column: SwiftUI’s adaptive grid reserves empty columns where Zen fills the available row. The next revision creates only the occupied flexible columns (and one column in collapsed mode), so a single essential fills the sidebar. It retains the native material and SF Symbol fallback. Fresh capture remains required.

### Divider persistence follow-up

The native split grid already allows dragging its eight-point dividers. The follow-up retains root and column proportions in normal sessions, keeps them while resizing the window, and resets them when pane composition changes. Private session state follows existing no-disk persistence rules. Actual pointer drags on both axes, resize stability and recreated-window geometry pass at `32b17e3`. The retrieved desktop capture shows 35% root and 65% left-column divisions; page rendering is still blank. Arbitrary divider trees, incremental split additions and split-group sidebar tabs remain unfinished.

Address cancellation now restores the current location and requests page focus after dismissing suggestions. A real Command-L/type/Escape check passes at `f8800b0`, verifying unchanged navigation and restored location/focus.

October 1 reference refresh [36794469990](https://github.com/super-original/serein-browser/actions/runs/36794469990) retains the pinned binary and now emits a compact evidence index. All 26 file hashes were checked. Light/dark expanded windows and expanded/collapsed folders were inspected again. At `32b17e3`, the sole essential uses the occupied full-width column in Serein; earlier adaptive-grid placement notes are historical, not the current layout. Active/inactive window state still needs a matched comparison.


### Live cross-window drag continuation

Tab rows and folder rows now share an original typed `Transferable` payload, exported as `dev.serein.sidebar-item`. A per-launch token and the source window/tab identity reject foreign or stale payloads before any model mutation. Dropping before a tab retains its category; dropping into a folder pins the moved owner and preserves its live preview. Existing native transfer logic carries WKWebView, history, zoom, document edits and extension tab identity. Cross-window private transfers remain rejected because each private window has a separate nonpersistent store; within-window private reordering is allowed.

The new runtime scenario locates two actual native tab controls and sends a real pointer drag between their visible sidebars, then checks live-object identity, script state, history, zoom, insertion order, document edits, privacy rejection, stale data, preview ownership and persisted folder membership. A direct handler fallback is separately labeled if the physical gesture fails. These additions await macOS 27 CI and inspected screenshots; no drag pass is claimed from compilation. Cross-window folder-tree transfer, multi-item drag, category-changing drops and drag-to-create-window are still missing.

At `7611908`, the exact-composition native attachment guard restores preview-close keyboard delivery to its live owner. Folder text submission and all folder scenarios pass again, and the original expanded-folder screenshot was inspected. Actual cross-window drag still fails despite passing controlled state/privacy checks; frontmost-window fixture correction is pending. Website desktop rendering remains blank.

At `21091e9`, all 17 cross-window drag scenarios pass, including real native pointer input; the handler fallback did not execute. The retrieved final moved-tab/preview capture was inspected. Native file selection and all 19 folder checks also pass. Category-changing/multi-item/folder-tree dragging and drag-to-new-window remain absent, and blank website rendering prevents complete visual parity.

### Lower-half tab placement

Tab rows now distinguish an upper-half drop (before) from a lower-half drop (after), including the last row. The existing typed payload, same-process token and private-store boundaries apply to both placements. Pinned tabs adopt the destination folder and preserve its explicit order; tab/view identity, history and edits remain unchanged. Three core tests cover end insertion, folder/session order and invalid targets. The macOS fixture adds an actual second pointer drag to the lower half of the final row; no model fallback satisfies that assertion. At `54c6c5e` all 19 drag checks and the three new core tests pass, including both actual pointer placements. The main run later times out in a separate update scenario, so this is partial checkpoint evidence. Folder-to-folder arbitrary insertion, category changes and drag-to-new-window remain gaps.

### Selected-tab drag groups (pending macOS verification)

Dragging one of several highlighted tabs now captures their sidebar order in the app-private payload. The host validates all members and the destination before moving any live view, preserves group order before/after a row or into a folder, and restores the complete destination selection. Stale/duplicate members, dropping onto the group itself, category-incompatible targets and cross-private-window moves are rejected. Unselected-tab drags retain singleton behavior. The new fixture includes an actual pointer drag of noncontiguous highlighted tabs, live JavaScript/document identity checks, atomic stale-group refusal, after-target ordering and folder membership. Pending execution is not a parity pass. Cross-window folder-tree transfer, category-changing drops and drag-to-create-window remain missing.

At `e2339f2`, [run 36812749134](https://github.com/super-original/serein-browser/actions/runs/36812749134) passes **all 10 selected-tab group checks**. The actual native pointer drag succeeds without the controlled fallback, both JavaScript sentinels and WKWebView identities survive, source/destination selection and group order are preserved, and invalid/private moves leave the group in place. Retrieved and inspected `56-selected-tab-drop.png` shows both highlighted folder members; it also retains the known blank WebKit desktop content. No cross-window folder-tree or drag-to-create-window support is claimed.
