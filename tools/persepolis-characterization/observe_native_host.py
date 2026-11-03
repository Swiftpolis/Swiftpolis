"""Sends real Persepolis the exact message its browser extension sends, and shows what it stores.

Usage, with the Persepolis checkout's own Python:

    PYTHONPATH=<persepolis repo> <persepolis repo>/venv/bin/python observe_native_host.py

It makes its own temporary home, so Persepolis's config and preferences stay untouched. It holds
Persepolis's single-instance lock, so Persepolis takes the "already running" path and opens no window.
"""

import fcntl
import json
import os
import struct
import subprocess
import sys
import tempfile

MESSAGE = {
    "url_links": [{
        "url": "https://example.com/file.zip",
        "cookies": "session=abc123; theme=dark",
        "useragent": "Mozilla/5.0 Test",
        "referrer": "https://example.com/page",
        "postdata": "",
    }],
    "version": "4.0.0",
}

READ_BACK = """
from persepolis.scripts.data_base import PluginsDB
import json
database = PluginsDB()
print(json.dumps(database.returnNewLinks()))
"""

PREPARE = """
from persepolis.scripts.data_base import PluginsDB
PluginsDB().createTables()
"""


def main():
    home = tempfile.mkdtemp(prefix='persepolis-host-')
    environment = dict(os.environ, HOME=home, CFFIXED_USER_HOME=home)
    os.makedirs(os.path.join(home, 'Library/Application Support/persepolis_download_manager/persepolis_tmp'))

    # Persepolis names its lock after the third part of the home path.
    lock_owner = home.split('/')[2]
    lock = open('/tmp/persepolis_exec_%s.lock' % lock_owner, 'w')
    fcntl.lockf(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)

    subprocess.run([sys.executable, '-c', PREPARE], env=environment, check=True)

    payload = json.dumps(MESSAGE).encode()
    host = subprocess.run(
        [sys.executable, '-c', 'from persepolis.scripts import persepolis', 'chrome-extension://test/'],
        input=struct.pack('@I', len(payload)) + payload,
        env=environment,
        capture_output=True,
        timeout=60,
    )
    length = struct.unpack('@i', host.stdout[:4])[0] if len(host.stdout) >= 4 else 0

    stored = subprocess.run(
        [sys.executable, '-c', READ_BACK], env=environment, capture_output=True, text=True, timeout=60
    )
    print(json.dumps({
        'sent': MESSAGE['url_links'][0],
        'host_exit_code': host.returncode,
        'host_reply': host.stdout[4:4 + length].decode(),
        'host_errors': host.stderr.decode()[-300:],
        'stored_for_the_add_link_window': json.loads(stored.stdout) if stored.stdout.strip() else stored.stderr[-300:],
    }, indent=2))


if __name__ == '__main__':
    main()
