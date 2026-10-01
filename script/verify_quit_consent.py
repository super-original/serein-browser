#!/usr/bin/env python3
"""Supervise only this app instance; unexpected exit fails this independent gate."""
import json
import os
import pathlib
import subprocess
import uuid

evidence = pathlib.Path("evidence/quit-consent").resolve()
evidence.mkdir(parents=True, exist_ok=True)
(evidence / "results.json").unlink(missing_ok=True)
combined = []
for native in [False, True]:
    root = evidence / str(uuid.uuid4())
    root.mkdir()
    app = pathlib.Path("dist/Serein.app/Contents/MacOS/Serein").resolve()
    with (root / "application.log").open("w") as stdout, (root / "application-error.log").open("w") as stderr:
        process = subprocess.Popen([str(app), "--test-root", str(root), "--quit-consent-test"] + (["--native-host-quit-test"] if native else []), stdout=stdout, stderr=stderr)
        try:
            code = process.wait(timeout=45)
        except subprocess.TimeoutExpired:
            process.terminate()
            try:
                process.wait(timeout=5)
            except subprocess.TimeoutExpired:
                process.kill()
                process.wait()
            raise AssertionError("Quit-consent app did not exit after fresh consent")
    assert code == 0, f"Quit-consent process exited with {code}"
    setup_error = root / "native-setup-error"
    assert not setup_error.exists(), setup_error.read_text() if setup_error.exists() else ""
    results = json.loads((root / "results.json").read_text())
    assert len(results) == 5 and all(item["passed"] for item in results), results
    session = json.loads((root / "session.json").read_text())
    assert len(session["windows"]) == 1 and len(session["windows"][0]["tabs"]) == (3 if native else 2), "Final consent did not save the current session"
    results.append({"name": "quit-exits-and-saves-current-session", "passed": True, "detail": "Supervised process exited with status 0; current tabs persisted"})
    if native:
        pid = int((root / "native-child-pid").read_text())
        assert pid > 0
        try:
            os.kill(pid, 0)
        except ProcessLookupError:
            pass
        else:
            raise AssertionError(f"Native child {pid} survived application exit")
        results.append({"name": "quit-reaps-active-native-child", "passed": True, "detail": "Actual extension port exchanged a response before quit; its child PID no longer exists after app exit"})
        for item in results:
            item["name"] = "native-" + item["name"]
    combined.extend(results)
(evidence / "results.json").write_text(json.dumps(combined, indent=2))
print(json.dumps(combined, indent=2))
