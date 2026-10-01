# Inspected September 30 captures

These are unaltered screenshots from actual macOS 27 hosted desktops, not generated UI images. The fixture is original Serein test content served over loopback. Zen branding belongs to Zen; references show its unmodified pinned 1.22.2b build for comparison ([provenance](../../LICENSES.md)).

| Zen 1.22.2b | Serein baseline `8fcac24` |
|---|---|
| ![Zen light](zen-light.png) | ![Serein blank content](serein-baseline-blank.png) |

Both use 1000×677 outer windows, 1× desktop scale and the light Field Notes fixture. The sidebar is 230 points; content starts at approximately x=246. Native materials/traffic lights differ intentionally. The absent Serein web content is a defect, not an adaptation. Native address-field height, favicon/essential geometry and richer split/group behavior still differ.

[Zen run](https://github.com/super-original/serein-browser/actions/runs/36705707876) supplies 14 separately inspected reference states and measured geometry. [Serein baseline run](https://github.com/super-original/serein-browser/actions/runs/36704547843) supplies the corresponding runtime captures and failing pixel gate.

![Safari also displays blank content](safari-blank.png)

The [corrected system probe](https://github.com/super-original/serein-browser/actions/runs/36705841148), source `b36599d`, drives Safari to the fixture and reports **Field Notes** as the actual window title. Safari's content is also blank. Its separate navigation bar makes this a diagnostic witness, not a geometry-matched Zen comparison. The same probe records successful public BGRA IOSurface allocations in the app process and errors in the WebKit path.

![Pinned Zen split focus reference](zen-split.png)

Zen outlines its focused split pane in the accent color. Serein adopts that focus cue; grouped split tabs remain unimplemented. No successful full-fidelity comparison is claimed while system WebKit desktop rendering fails.

| Serein site settings | Native consent sheet |
|---|---|
| ![Site permission settings](site-settings.png) | ![Camera permission prompt](permission-prompt.png) |

These two screenshots are from [run 36705846607](https://github.com/super-original/serein-browser/actions/runs/36705846607), source `b36599d`. Both were inspected. Settings use a scrollable native form; camera/microphone rows are visible and further choices continue below. The consent sheet shows both origins and distinct Allow Once, Deny and Always Allow choices. These are real native UI captures, with in-process test responses; no physical camera capture is claimed.


| Serein primary pane focused | Serein secondary pane focused |
|---|---|
| ![Primary focus](serein-split-primary.png) | ![Secondary focus](serein-split-secondary.png) |

[Run 36707376209](https://github.com/super-original/serein-browser/actions/runs/36707376209), exact source `acf9beb`, produced these inspected captures after correcting the nested native split-host safe area. Both page borders begin around y=39 (eight points below the window top), matching the reference's content inset. The focus outline and address follow the selected pane without swapping the panes. The failed WebKit content area remains explicit.

## Extension management

[Run 36710297851](https://github.com/super-original/serein-browser/actions/runs/36710297851), commit `b319b98`: the actual native management sheet with the controlled MV3 fixture installed. Inspected for legibility, clipping, enabled state and the persistent-access notice. The underlying website is still affected by the separate desktop rendering failure.

![Actual extension management sheet](extension-management.png)

[Run 36710657986](https://github.com/super-original/serein-browser/actions/runs/36710657986), `54ae12a`, verified the production Remove confirmation appears above the library sheet and Cancel preserves the extension. The actual Install chooser also opened and canceled successfully. All 100 runtime checks passed; the separate desktop content gate remained failed.

![Actual extension removal confirmation](extension-removal-confirmation.png)

## Download controls

[Run 36712970628](https://github.com/super-original/serein-browser/actions/runs/36712970628), `3582856`: actual paused-download management sheet, inspected for legible status, Resume/Cancel controls and privacy/persistence explanation. The same run passed 30 unit tests and 117 runtime checks, including production pause/resume and complete 8 MiB byte integrity. Private download activity did not modify the normal download-history file's content or modification time. No cross-launch resume or native Save-panel automation is claimed.

![Actual paused download controls](downloads-paused.png)

Multiselection: [`serein-multiselection.png`](serein-multiselection.png) from [36713799565](https://github.com/super-original/serein-browser/actions/runs/36713799565) and [`zen-multiselection.png`](zen-multiselection.png) from [36713797409](https://github.com/super-original/serein-browser/actions/runs/36713797409), both `7ce1cad`. Both inspected: two selected tabs visible, same 1000×677 window. Serein uses an accent fill for the nonactive selection and gray active fill; Zen uses near-white rounded surfaces for both. Zen content renders; Serein content remains blank. Native selection checks passed; the extension scenario failed because `tabs.highlight` is undefined. This pair is comparison evidence, not a passing full-fidelity assertion.

[`download-save-panel.png`](download-save-panel.png), inspected from [36717038331](https://github.com/super-original/serein-browser/actions/runs/36717038331), `cfc333d`: native keyboard actions selected the runtime folder and `native-save-result.txt`; the screenshot shows that actual destination/name and enabled Save button. The pre-probe checkpoint passed save completion, exact path, bytes and cancellation. It also passed all four stale-navigation confirmation scenarios. That checkpoint contains 136 passing checks out of 138; the two MV2/MV3 multiselection query checks failed, and the later native-message experiment terminated before final results. This is scoped evidence, not an overall successful workflow.

Exact verified source `8245e2a`, [run 36719782728](https://github.com/super-original/serein-browser/actions/runs/36719782728): [`download-save-panel-8245e2a.png`](download-save-panel-8245e2a.png), [`network-error-8245e2a.png`](network-error-8245e2a.png), and [`multiselection-8245e2a.png`](multiselection-8245e2a.png) were downloaded from artifact 11097702508 and inspected. The Save filename/folder, unavailable URL/Reload control and selected-tab states are legible. WebKit webpage content remains blank; successful native chrome captures do not satisfy the page-rendering gate. The pinned [`zen-multiselection.png`](zen-multiselection.png) remains the matching layout reference.
