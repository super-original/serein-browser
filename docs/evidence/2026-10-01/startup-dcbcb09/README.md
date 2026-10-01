# Independent application startup measurements

[macOS 27 run 36853136282](https://github.com/super-original/serein-browser/actions/runs/36853136282), published source `dcbcb09077011250918ddb46f7f3fed88f082075`. GitHub checked out synthetic PR merge `f033af4e160d907bde978a62839150d68fa9945b`; its tree `62e643289778389da26178e8e4541b26cb7071c6` was independently verified to equal the published head tree. The raw report preserves the actual checkout commit. Later workflows explicitly check out the source head.

Standard free ARM64 macOS 27.0 runner, Xcode 27.1, SDK/minimum 27.0. One untimed seed launch, followed by five fresh-profile and five production one-tab session restores in alternating order. Every sample runs in a new actual app process and exits through normal termination. No installed extensions. OS/WebKit caches stay warm; this is not cold-boot startup or a physical-Mac measurement.

| Workload / endpoint | Process spawn to observed readiness, median (min–max) | Swift main entry to readiness, median (min–max) |
|---|---|---|
| Fresh profile: one visible native window with default blank tab | 490.21 ms (443.65–657.23) | 427.18 ms (411.55–568.75) |
| Restored local page: native attachment, completed navigation and correct JavaScript document identity | 1,363.28 ms (1,345.12–1,454.22) | 1,333.89 ms (1,285.42–1,395.76) |

All ten readiness assertions pass. The parent timer includes process spawning, atomic readiness-file publication and 10 ms polling; the app timer excludes loader work before Swift main. The workloads have different readiness endpoints and should not be treated as equivalent rendering measurements. Neither establishes visible-frame latency, LaunchServices launch time, extension-heavy startup, scrolling, energy or physical-device performance. The separate desktop WebKit rendering gate still fails.

[Raw per-launch JSON](startup-performance.json). Reproduce with `python3 script/measure_startup.py` after the documented macOS build; it starts its own deterministic fixture server and records logs under `evidence/startup`. Original workflow evidence SHA-256: `cca36cf7e2edf5ebcf0d60359bb7f83faa4ea7973417d284f4954f67f2c4b38d`.
