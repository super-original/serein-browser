# Extension compatibility — target not achieved

**Full Chrome, Firefox and Safari extension compatibility remains the target and is not supported by this build.** The implementation uses public system WKWebExtension APIs; it does not translate arbitrary extensions into page scripts or substitute Chromium/Gecko.

## Format matrix

| Format | Current status | Exact scope |
|---|---|---|
| Chrome Manifest V2 | Partial | ZIP/unpacked loading; controlled persistent-background fixture passes limited semantics. CRX validation/store installation absent. |
| Firefox Manifest V2 | Partial | XPI/unpacked loading; Firefox-specific semantics and APIs not implemented universally. |
| Chrome Manifest V3 | Partial | Controlled service-worker fixture passes limited semantics. Lifetime, wakeup, DNR, offscreen and full Chrome API conformance not established. |
| Firefox Manifest V3 | Untested semantics | Manifest number is accepted, which is not proof of Firefox MV3 lifecycle behavior. |
| Safari Web Extensions | Partial | Shared manifest resources can load through public WebKit; packaged `.appex`/App Store installation is not implemented. |
| Native Safari App Extensions | Blocked / unsupported | No documented third-party hosting entry point found for arbitrary SafariServices native extension handlers. |
| Legacy Safari `.safariextz` and earlier | Unsupported | No loader or compatibility runtime. |

## API and lifecycle matrix

| Family | Status | Evidence / missing work |
|---|---|---|
| Install / validate | Implemented, partial formats | Path, duplicate, size, symlink and manifest checks; source consent; no publisher-signature validation |
| Enable / disable / remove | Partial | Fixture disable stops injection; installed records persist; complete UI/removal tests pending |
| Updates | Unimplemented | No authenticated update protocol or permission-diff upgrade flow |
| Permissions / host access | Partial | Install prompts; fixture denied hosts do not inject; runtime permission prompts; temporary per-site overrides |
| Private access | Unsupported by policy in this build | No extension controller in private web views; no opt-in UI |
| Tabs / windows | Partial | Native bridges, navigation, creation, focus, closure, pinning, duplication and window state; query tested; event ordering/multiselect incomplete |
| Navigation events | Partial / untested semantics | WebKit engine events plus host tab changes; no exhaustive ordering/redirect/frame suite |
| Content scripts / isolated worlds | Partially verified | Controlled DOM injection succeeds after grant; page cannot see extension-global variable |
| Frames / dynamic scripting | Untested | No nested-frame, origin-inheritance or executeScript conformance suite |
| MV2 persistent backgrounds | Partially verified | Message → storage → tabs query → response exercised |
| MV3 service workers | Partially verified | Same controlled path; suspension, restart and queued-event semantics not established |
| Runtime messaging | Partially verified | One-shot content-to-background messaging; ports/cross-extension semantics untested |
| Storage | Partially verified | Local counter survives unload/reload with stable context ID; sync/quota/restart/error semantics untested |
| Cross-origin network | Untested | Native WebKit permission path; no complete fetch/CORS/header test suite |
| Cookies | Untested extension API | Browser normal/private cookie isolation tested separately |
| Downloads / history / bookmarks | Incomplete | Native browser features exist; not equivalent to implementing these extension API families |
| Context menus | Partial / untested | Engine and action-menu hooks exist; full native menu integration not complete |
| Request interception | Blocked or unverified per operation | Safari's documented blocking webRequest differences are material; no equivalent engine-level implementation added |
| Declarative network rules | Untested | API availability is not evidence of matching Chrome/Firefox rule limits or semantics |
| Native messaging | Unsupported | Manifest requests fail closed; no arbitrary native process access |
| External messaging / devtools | Unsupported | Manifest installation fails with a clear error |
| Commands | Partial | Public performCommand(for:) routed after native key equivalents; conflicts and real extension shortcut semantics unverified |
| Notifications | Untested | No complete consent/delivery/action semantics suite |
| Actions / popups / options | Partial | Native toolbar button and public WebKit popover/options routing; real UI scenarios pending |

The current upstream [WebExtension namespace source](https://github.com/WebKit/WebKit/blob/main/Source/WebKit/WebProcess/Extensions/API/WebExtensionAPINamespace.cpp) contains compile-time/runtime feature gates for some families. Discovering a symbol there is **not** proof that the runner's system WebKit exports or enables it. No private flags are enabled.

## Controlled conformance scenarios

Fixtures are original source under `Fixtures/Extensions`, version 1.0.0, MV2 and MV3. [Run 35242885738](https://github.com/super-original/serein-browser/actions/runs/35242885738) passed both generations for: denied-host noninjection; allowed-host injection; background messaging with sender tab identity; storage write/read; browser tab query; isolated global scope; storage continuity across unload/reload; and disabling followed by navigation.

These are narrow semantic tests. They do not prove worker eviction, full frame isolation, every permission boundary, restart persistence, event ordering, all API families, or compatibility with arbitrary real extensions.

## Real package audit

Pinned sources and SHA-256 values are in [`extension-catalog.json`](../Fixtures/extension-catalog.json). The workflow downloads the original packages into an ephemeral directory and does not redistribute them. No credentials or live password vaults are used. The **scenario is package validation and context loading without permission grants**, followed by unload/data removal. None of these rows is marked functionally compatible.

| Package | Version / manifest | Observed result |
|---|---|---|
| [uBlock Origin, Chromium ZIP](https://github.com/gorhill/uBlock/releases/tag/1.75.0) | 1.75.0 / MV2 | Loads after handling the archive's enclosing directory. Blocking permission absent from WebKit's returned requested-permission set; blocking semantics not verified. |
| [uBlock Origin, Firefox XPI](https://github.com/gorhill/uBlock/releases/tag/1.75.0) | 1.75.0 / MV2 | WebKit reports invalid/empty command manifest entry; Serein rejects rather than silently claim success. |
| [Stylus, Chrome](https://github.com/openstyles/stylus/releases/tag/v2.4.13) | 2.4.13 / MV3 | Same command-validation rejection. Page styling not exercised. |
| [Violentmonkey, WebExtension](https://github.com/violentmonkey/violentmonkey/releases/tag/v2.49.0) | 2.49.0 / MV2 | Same command-validation rejection. Userscript execution not exercised. |
| [Bitwarden, Chrome](https://github.com/bitwarden/clients/releases/tag/browser-v2026.9.0) | 2026.9.0 / MV3 | Context loads without grants. Autofill, unlock, native integration and vault behavior untested. |
| [DownThemAll](https://addons.mozilla.org/firefox/addon/downthemall/) | 4.15.1 / MV2 | Context loads without grants. Its requested downloads/history/session capabilities are not all returned by WebKit. Download management not verified. |
| [Tab Session Manager](https://addons.mozilla.org/firefox/addon/tab-session-manager/) | 7.4.0 / MV3 | Context loads without grants. Tab groups, identity, download and restoration semantics not verified. |

Evidence: [run 35244059174](https://github.com/super-original/serein-browser/actions/runs/35244059174), `real-extension-results.json`. The run also contains a separate capture-harness failure; that is not an extension pass or failure. Loading packages while engine capabilities are omitted is a reason to withhold compatibility claims, not evidence that missing APIs work.

## Release blockers

A production compatibility release requires a much broader semantics suite and explicit host/engine gap resolution. Native Safari formats and engine-internal interception are major restrictions. Updating, signature validation, per-site persistent policies, private opt-in, native-host isolation and API coverage are additional unimplemented work. No full custom-engine build/distribution/security-update plan has been proven feasible within the required standard free runner resources.
