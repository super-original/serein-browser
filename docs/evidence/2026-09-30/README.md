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
