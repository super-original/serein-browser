#!/usr/bin/env python3
"""Supervise only this app instance; unexpected exit fails this independent gate."""
import json
import pathlib
import subprocess
import uuid

evidence = pathlib.Path("evidence/quit-consent").resolve()
evidence.mkdir(parents=True, exist_ok=True)
(evidence / "results.json").unlink(missing_ok=True)
root = evidence / str(uuid.uuid4())
root.mkdir()
app = pathlib.Path("dist/Serein.app/Contents/MacOS/Serein").resolve()
with (root / "application.log").open("w") as stdout, (root / "application-error.log").open("w") as stderr:
    process = subprocess.Popen([str(app), "--test-root", str(root), "--quit-consent-test"], stdout=stdout, stderr=stderr)
    try:
        code = process.wait(timeout=30)
    except subprocess.TimeoutExpired:
        process.terminate()
        try:
            process.wait(timeout=5)
        except subprocess.TimeoutExpired:
            process.kill()
            process.wait()
        raise AssertionError("Quit-consent app did not exit after fresh consent")
assert code == 0, f"Quit-consent process exited with {code}"
results = json.loads((root / "results.json").read_text())
assert len(results) == 3 and all(item["passed"] for item in results), results
session = json.loads((root / "session.json").read_text())
assert len(session["windows"]) == 1 and len(session["windows"][0]["tabs"]) == 2, "Final consent did not save the current session"
results.append({"name": "quit-exits-and-saves-current-session", "passed": True, "detail": "Supervised process exited with status 0; both tabs persisted"})
(evidence / "results.json").write_text(json.dumps(results, indent=2))
print(json.dumps(results, indent=2))
