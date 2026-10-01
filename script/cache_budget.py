#!/usr/bin/env python3
"""Optional compiler cache only; never increase GitHub's storage allowance."""
import json
import os
from pathlib import Path
import subprocess
import urllib.request

save = False
try:
    # du counts allocated blocks and avoids following compiler-cache symlinks.
    local_bytes = int(subprocess.check_output(['du', '-sk', '.build'], text=True).split()[0]) * 1024
    headers = {'Accept': 'application/vnd.github+json'}
    token = os.environ.get('SEREIN_CACHE_READ_TOKEN')
    if token:
        headers['Authorization'] = 'Bearer ' + token
    request = urllib.request.Request(
        'https://api.github.com/repos/super-original/serein-browser/actions/cache/usage',
        headers=headers)
    with urllib.request.urlopen(request, timeout=10) as response:
        usage = json.load(response)
    existing_bytes = usage['active_caches_size_in_bytes']
    assert isinstance(existing_bytes, int) and existing_bytes >= 0
    save = 0 < local_bytes <= 512 * 1024**2 and existing_bytes + local_bytes <= 8 * 1024**3
    print(f'Compiler cache: {local_bytes} bytes; existing repository caches: {existing_bytes} bytes; save={save}')
except Exception as error:
    # Cache failure must not block a clean-source build or enable paid capacity.
    print(f'Compiler cache skipped: {type(error).__name__} status={getattr(error, "code", "unavailable")}')
with Path(os.environ['GITHUB_OUTPUT']).open('a') as output:
    output.write(f'save={str(save).lower()}\n')
