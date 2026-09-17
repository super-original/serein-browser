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
| Reorder | P | Drag strings within the same tab kind; cross-window dragging absent |
| Pins and essentials | I | Essentials span workspaces; pins preserve reset URL |
| Multiple workspaces | P | Create, rename, remove, switch; no containers or per-workspace cookie stores |
| Expanded/collapsed sidebar | I | Visual inspection required across resizing and focus |
| Compact mode | P | Edge reveal/hide; Zen's complete toolbar variants absent |
| Split views | P | Two horizontal panes; no four-pane grid, split-group tabs or drag composition |
| Multiple windows / moving tabs | P | Normal live-tab transfer; isolated private transfer deliberately rejected |
| Persistent sessions | P | Tab/workspace/sidebar restoration; not full history-stack/window restoration |
| Bookmarks / history / find | I | Basic library, search, clear, find navigation |
| Downloads | P | Native save/cancel/reveal; no resume or durable download history |
| Private browsing | I | Nonpersistent store per window; no saved private tabs/history; extensions excluded |
| File selection / JS dialogs | I | Native panels; broader UI automation pending |
| Site permissions / media | P | Per-page camera/microphone consent; policy manager incomplete |
| Fullscreen | P | Native window/fullscreen WebKit preference; media runtime coverage incomplete |
| Loading / errors / process recovery | P | Visible states; real process-crash injection pending |
| Settings | P | Appearance, sidebar, website data clearing; advanced policies absent |
| Glance / link preview | U | Not implemented |
| Folders / live folders | U | Not implemented |
| Tab groups / multiselect | U | Not implemented |
| Containers / profiles / per-site isolation | U | Not implemented |
| Zen Mods / themes / gradient editor | U | Not implemented; native glass adaptation is separate |
| Sync / account / import wizard | U | Not implemented |
| Tab unloading | P | Manual with warning; no automatic suspension |
| Keyboard customization | U | Fixed native shortcuts only |
| Picture-in-picture / screenshot tools | U | Not implemented as browser commands |
| Full extension compatibility | U | See detailed matrix; target remains unmet |

This checklist is intentionally not a claim of complete Zen parity.
