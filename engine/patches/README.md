# WebKit phase-order experiment — not adopted

This patch is **uncompiled and unexecuted**. Serein still links system WebKit. No
workflow currently applies it, and no compatibility or rendering fix is claimed.
The ongoing unmodified-engine signing/hardening audit must be resolved before a
patched engine can be safely executed or distributed.

Base: WebKit [`131cc0a7111b3a8c4038989d7bd5cee49c1ad7f7`](https://github.com/WebKit/WebKit/tree/131cc0a7111b3a8c4038989d7bd5cee49c1ad7f7).
`phase-source.json` records SHA-256 values for each original and proposed file.
`git apply --check`, application to copies of all four pinned files, and comparison
with all four proposed hashes passed in the cloud checkout. These are applicability
checks, not C++ compilation or runtime tests.

## Concrete defect and proposed change

The pinned `WebExtensionContext.cpp` maps `DocumentIdle` to `DocumentEnd` and leaves
a FIXME for idle injection. `LocalFrame::injectUserScripts` iterates script worlds;
therefore an idle script in one world can run before an end script in another.
Serein's controlled end/idle fixture and original Formatter exhibit this ordering
failure intermittently on system WebKit. This explains a possible mechanism; the
system binary's exact correspondence to the pinned upstream source is not proven.

The patch adds a distinct internal injection phase and its IPC enum serialization.
After all end scripts run, `FrameLoader::finishedParsing` runs the idle phase if
its original document still belongs to that frame. This is a deterministic phase
boundary immediately after document-end, not a general idle scheduler. It does
not change extension source, execution world, host permissions, request filtering,
process sandboxing, signing, or the public WKUserScript start/end API.

## Acceptance work still required

- Compile the complete dependency scheme against the same macOS 27 SDK with the
  bounded free-runner procedure; audit all enum switches and generated IPC code.
- Establish valid nested signatures, hardened runtime/library validation and a
  supported helper-loading path. Do not re-sign away required restrictions.
- Run end/idle scripts in both MAIN/isolated directions, multiple extensions,
  dynamic registration, frames and initial empty documents. Test navigation,
  document replacement, `document.open` reentrancy, script exceptions and unload.
- Repeat the original unmodified Formatter and controlled ordering fixtures over
  multiple launches. Preserve system-engine failures as separate evidence.
- Inspect actual macOS 27 desktop content; this phase patch does not purport to
  repair the separate IOSurface/desktop-composition failure.
- Validate source/binary licensing, security-update rebasing, process resource
  usage and distribution before considering adoption.

Original-file copyright notices and redistribution conditions are preserved in
`UPSTREAM-NOTICES.txt`; applying the patch leaves their source headers intact.
No third-party binary is distributed here. The broader adoption requirements are
in [WEBKIT_FEASIBILITY.md](../../docs/WEBKIT_FEASIBILITY.md).
