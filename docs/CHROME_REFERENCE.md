# Pinned Chrome extension reference

The free `xcode-27` runner's preinstalled Chrome for Testing and ChromeDriver **154.0.8037.57** provide a second reference for the original JSON Formatter 0.8.0 source build. This does not change Serein's WebKit engine. Runtime results are pending.

The [runner inventory](https://github.com/actions/runner-images/blob/xcode-27-arm64/20260928.0222/images/macos/xcode-27-arm64-Readme.md) lists both versions. Its [installation script](https://github.com/actions/runner-images/blob/main/images/macos/scripts/build/install-chrome.sh) establishes the application and driver paths. The reference verifies both actual versions, macOS 27/ARM64, upstream distribution identity, signature diagnostics and executable hashes; inventory drift fails explicitly instead of silently changing the baseline. No browser or toolchain is installed on the user's Mac.

[ChromeDriver's documented unpacked-extension loading](https://developer.chrome.com/docs/chromedriver/extensions) supplies the original built directory through `load-extension`. The original manifest and scripts are unchanged; the existing pinned source/compiler builder records resource hashes. A fresh owned profile, visible browser window and loopback fixture are used. No sandbox, web-security or signature bypass is requested. The browser and its profile are exclusively reference automation, not production browser integration.

Three checks observe isolated formatting, the original raw JSON text and the page's MAIN-world global. A desktop screenshot is retained for actual inspection. No extension package or third-party executable is uploaded. A source build is not a signed store package, and these checks do not establish general installation, permission or background-worker lifecycle compatibility. Chrome's [testing documentation](https://developer.chrome.com/docs/extensions/how-to/test/end-to-end-testing) also warns that ChromeDriver's attached debugger can prevent ordinary service-worker termination; no lifecycle conclusion is drawn here.

The first attempt at `28e1a30`, [run 36859734385](https://github.com/super-original/serein-browser/actions/runs/36859734385), stopped before browser launch because its pin from the unversioned inventory was 153.0.8010.52, while the actual bundle reported 154.0.8037.57. The retrieved artifact confirms no scenario executed. The exact dated image manifest above independently lists Chrome for Testing and ChromeDriver 154.0.8037.57; the follow-up pins that pair and records both versions before asserting them. No semantic success or screenshot is claimed from the failed preflight.

The same original controlled downloads fixture is also prepared for a Chrome MV3 service worker, selecting the native browser/chrome namespace without changing its calls or assertions. Downloads are confined to an owned temporary directory through profile preferences. Evidence retains both metadata freshness and independent physical removal; Chrome explicitly documents asynchronous existence checking at most once per ten seconds, so the fixture's four-second freshness failure alone is not a violation of that contract. Reference MV2 is not claimed on this current Chrome build. Downloads events are tested while the worker is awake; its ordinary idle lifecycle remains outside this scenario.

At `d8cce57`, [run 36861666621](https://github.com/super-original/serein-browser/actions/runs/36861666621) confirms both exact versions but stops before launch because deep signature verification reports “code has no resources but signature indicates they must be present.” Investigation of the [official pinned archive](https://storage.googleapis.com/chrome-for-testing-public/154.0.8037.57/mac-arm64/chrome-mac-arm64.zip) finds no CodeResources seals at all. Its launcher SHA-256 `4f82263da1a7ed4b71be76d6501bb7edc13c6573b8d950197147ee5776edcf3b` matches the preinstalled binary exactly. This alone does not validate its remaining resources.

The follow-up verifies the complete official archive (191,429,663 bytes, SHA-256 `0e6b3439469c1b8b95b2e89c72ea29f7af00fb2c28a8878358a0b6002b6d3a64`) and then compares every installed regular file, symlink target and executable bit, rejecting missing or additional files. It verifies the driver executable SHA-256 `ad8c4613ef867bd4ee803fd4ac39ee865fa2e53db78170331cc92d64dc3db0f0` against the official [driver archive](https://storage.googleapis.com/chrome-for-testing-public/154.0.8037.57/mac-arm64/chromedriver-mac-arm64.zip) (9,302,980 bytes, archive SHA-256 `97a96253f407512086744a953a3def997461fc7c37882b4f9cca297bab5f644e`). The earlier failed signature preflight remains recorded. Only its exact known unsealed-distribution diagnostic is permitted after complete provenance verification; other failures stop the scenario.

This is an unmodified upstream **testing** build, not a signed/notarized production-browser claim. Google's [scope guidance](https://developer.chrome.com/docs/automation-and-testing/chrome-for-testing) limits it to trustworthy test content. The reference uses owned loopback fixtures. No files are re-signed, quarantine attributes removed, platform checks bypassed, or security settings changed. If ordinary browser launch fails, that failure is retained. The downloaded archive is deleted after comparison; browser binaries are not redistributed.

The comparison implementation passes six local tests covering an exact tree and changed bytes, extra/missing files, redirected links and executable-mode changes. It also verified a freshly extracted copy of the real official archive in the cloud: 340 regular application files and five symlinks. That disposable copy was removed immediately. This validates the comparison code, not the installed macOS runner copy or browser execution; those remain pending.

## First executed Chrome reference (41707ef, October 1)

[Run 36864204084](https://github.com/super-original/serein-browser/actions/runs/36864204084)
verified the complete installed distribution (340 files, five symlinks) against the pinned
upstream archive and launched Chrome normally. All three original Formatter document
checks passed: formatted DOM, parseable raw JSON, and the MAIN-world `window.json`
object. This is narrow execution evidence, not universal compatibility or visible rendering.

Both retrieved desktop images were inspected. They show the fixture Python local-network
permission dialog over the desktop, not a visible Chrome window. A follow-up denies that
optional access using the normal system dialog and activates the test browser before
capture; no privacy database, signature, quarantine or sandbox policy is changed.

The download fixture created three real files and received created/filename/completion
events, then aborted with `Invalid orderBy field` for `orderBy: ['id']`. No download
assertions completed. Gecko had accepted that field. The follow-up retains this exact
field-support observation and uses documented `startTime` sorting to continue independent
checks ([Chrome downloads reference](https://developer.chrome.com/docs/extensions/reference/api/downloads)).
The four-second existence-refresh observation remains unchanged and is not a documented
Chrome deadline. Original failed results remain in
[artifact 11163312075](https://github.com/super-original/serein-browser/actions/runs/36864204084/artifacts/11163312075),
ZIP SHA-256 `c7b0bba114828e5855cd71020f50c7b4612ac9fe20c3c6519c4933755a029e78`.

## Visible Chrome and complete download scenario (10e984e)

[Run 36865511517](https://github.com/super-original/serein-browser/actions/runs/36865511517)
again passes all three original Formatter checks. Both desktop captures were retrieved
and inspected: the original JSON tree/Raw/Parsed controls and the Field Notes test page
are visibly rendered. The optional Python local-network request was denied normally.
No engine substitution in Serein follows from this separate reference browser.

Chrome downloads completes **15/16** checks. Physical removal, existence refresh, ordered
created/completed events, erase events, and ascending/descending time sorts pass. The
positive/negative query assertion fails. The original failure remains; follow-up diagnostics
record each returned ID set, because a boolean alone cannot distinguish empty, extra or
misordered matches. Chrome's [query contract](https://developer.chrome.com/docs/extensions/reference/api/downloads#type-DownloadQuery)
documents negative terms, so this result must not be relabeled as a known unsupported feature.

The same fixture in [Gecko run 36865511502](https://github.com/super-original/serein-browser/actions/runs/36865511502)
passes **15/16** in each manifest generation, with only four-second existence refresh
failing; the file is actually deleted. Gecko accepts ID sorting, includes the exact
`startedAfter` boundary, matches differently cased `filename`, and returns the completed
items for the epoch `endedBefore` query (their `endTime` is null). Chrome rejects ID sorting,
excludes the exact start boundary, returns no differently cased filename matches, and
returns no completed items for `endedBefore` epoch. These are bounded observed semantics,
not universal conformance results. Serein's extension downloads namespace remains absent.

Evidence: [Chrome artifact 11163960666](https://github.com/super-original/serein-browser/actions/runs/36865511517/artifacts/11163960666)
(SHA-256 `417c1a896edaf82a09c03dc302c8e5274eaf8ae39bbab81a66e240291c9b7ba1`),
[Gecko artifact 11163416403](https://github.com/super-original/serein-browser/actions/runs/36865511502/artifacts/11163416403)
(SHA-256 `746a9d00cd9f8a739b8257361dc9cfaddde07b1c3955d437d24ae3848a46763d`).

At `1de9b3a`, [run 36867377515](https://github.com/super-original/serein-browser/actions/runs/36867377515)
records the exact query results: positive `alpha` returns IDs `[3,1]`; negative-only `-two`
and combined `alpha,-two` both return `[3]` (the `alpha-two.txt` item). The pinned
[Chromium MatchesQuery implementation](https://github.com/chromium/chromium/blob/73c14f6228d7cd537c855007e8f88678969cc0eb/chrome/browser/download/download_query.cc#L265)
searches each literal term, explaining the observed dash behavior. This conflicts with the
current documentation's negative-term description. Keep the failed assertion and distinguish
observed Chrome-version behavior, Gecko behavior and documented behavior when implementing
an adapter; do not silently change browser-native search to match this version-specific result.
The first Formatter desktop capture in this run shows only the activated app's menu bar and
desktop; the later downloads capture visibly renders the page. Both were inspected. The prior
`10e984e` Formatter capture remains the visible Formatter evidence. Three document checks
still pass and downloads remains 15/16. [Artifact](https://github.com/super-original/serein-browser/actions/runs/36867377515/artifacts/11164233434),
SHA-256 `034be49cc383837293c0c3d20420508553bb93cb8be0faaef731099b399ce12f`.

### Desktop readiness follow-up

The `1de9b3a` Formatter capture caught a black desktop during activation although its three document checks passed; the later downloads capture visibly rendered Field Notes. Earlier visible Formatter evidence is retained. The next reference compiles a small public AppKit/CoreGraphics probe, verifies the exact ChromeDriver-reported PID and executable, activates only that process and requires its one normal on-screen 1000×677 window to remain stable for one second (ten-second bound). It records original window metadata and still captures the actual desktop on readiness failure. This is pending native verification and does not assert that a visible window's website pixels rendered; screenshots still require inspection. No permission databases or security settings change.

At `478c926`, [run 36871834535](https://github.com/super-original/serein-browser/actions/runs/36871834535), both readiness probes pass for PID 8973/window 31 at (10,31,1000,677), stable for 1.086 and 1.213 seconds. Both original desktop screenshots were retrieved and inspected: Formatter's JSON tree and the Field Notes page visibly render. Formatter remains 3/3; downloads remains 15/16 with only the documented-versus-observed negative-query difference. Evidence SHA-256: `d3fccb982455b66bab8e8673605bc404068a8cefdfb5c1d38f98f0a09fc18136`. This verifies the capture follow-up without changing the failed conformance expectation.
