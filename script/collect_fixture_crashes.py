#!/usr/bin/env python3
"""Retain reports for recorded fixture PIDs; dismiss only Serein's crash notice."""
import json
import pathlib
import re
import shutil
import subprocess

root = pathlib.Path('evidence').resolve()
output = root / 'fixture-crashes'
output.mkdir(parents=True, exist_ok=True)
pids = set()
main_pid = root / 'runtime/app-pid'
if main_pid.exists():
    pids.add(int(main_pid.read_text()))
for path in (root / 'extension-origins').glob('*/process-outcome.json'):
    pids.add(json.loads(path.read_text())['pid'])

for source in (pathlib.Path.home() / 'Library/Logs/DiagnosticReports').glob('Serein*'):
    if not source.is_file() or source.stat().st_size > 8 * 1024 * 1024:
        continue
    text = source.read_text(errors='replace')
    pid = None
    if source.suffix == '.ips':
        decoder = json.JSONDecoder()
        remainder = text.strip()
        try:
            while remainder:
                value, offset = decoder.raw_decode(remainder)
                if value.get('procName') == 'Serein':
                    pid = value.get('pid')
                remainder = remainder[offset:].strip()
        except (ValueError, AttributeError):
            continue
    else:
        match = re.search(r'^Process:\s+Serein\s+\[(\d+)\]', text, re.M)
        if match:
            pid = int(match[1])
    if pid in pids:
        shutil.copy2(source, output / source.name)
        print('Retained fixture crash report:', source.name, 'PID', pid)

# A delayed crash notice can cover the next independent app. Never choose Reopen,
# dismiss another application's notice, or disable OS crash reporting globally.
script = '''
on run arguments
  tell application "System Events"
    repeat with processName in {"UserNotificationCenter", "Problem Reporter", "ReportCrash"}
      if exists process (contents of processName) then
        tell process (contents of processName)
          repeat with notice in windows
            if exists button "Ignore" of notice then
              set matched to false
              repeat with uiElement in entire contents of notice
                try
                  if value of uiElement is "Serein quit unexpectedly." then set matched to true
                end try
              end repeat
              if matched then
                if item 1 of arguments is "dismiss" then click button "Ignore" of notice
                return "matched"
              end if
            end if
          end repeat
        end tell
      end if
    end repeat
  end tell
  return "none"
end run
'''
try:
    probe = subprocess.run(['osascript', '-', 'inspect'], input=script, text=True, capture_output=True, timeout=5)
    if probe.returncode == 0 and probe.stdout.strip() == 'matched':
        capture = output / 'serein-crash-notice.png'
        if not capture.exists():
            subprocess.run(['screencapture', '-x', str(capture)], check=True, timeout=5)
        result = subprocess.run(['osascript', '-', 'dismiss'], input=script, text=True, capture_output=True, timeout=5)
        assert result.returncode == 0 and result.stdout.strip() == 'matched', 'Exact crash notice dismissal failed'
        print('Captured and dismissed exact Serein crash notice with Ignore')
    elif probe.returncode:
        print('Crash notice inspection unavailable:', probe.stderr.strip())
except subprocess.TimeoutExpired:
    print('Crash notice inspection exceeded its owned child deadline; no broad dismissal attempted')
