"""Runs Persepolis's real HTTP engine against a misbehaving local server and records what it does.

Usage, with the Persepolis checkout's own Python:

    HOME=$(mktemp -d) PYTHONPATH=<persepolis repo> <persepolis repo>/venv/bin/python \
        observe_http_engine.py [scenario ...]

HOME must be a temporary folder, because Persepolis's logger writes into the config folder under it.
Results print as JSON. docs/persepolis-observed.md records what they meant.
"""

import base64
import hashlib
import json
import os
import shutil
import sys
import tempfile
import threading
import time
import urllib.parse
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

from persepolis.scripts import persepolis_lib_prime

MIB = 1024 * 1024
PATTERN = bytes(i % 251 for i in range(251 * 4096))


def content(start, length):
    """The byte at offset N is always N % 251, so any misplaced byte changes the hash."""
    out = bytearray()
    while length > 0:
        offset = start % 251
        take = min(length, len(PATTERN) - offset)
        out += PATTERN[offset:offset + take]
        start += take
        length -= take
    return bytes(out)


def expected_sha(size):
    digest = hashlib.sha256()
    for start in range(0, size, MIB):
        digest.update(content(start, min(MIB, size - start)))
    return digest.hexdigest()


class Log:
    def __init__(self):
        self.lock = threading.Lock()
        self.requests = []
        self.active_gets = 0
        self.max_active_gets = 0
        self.ports = set()
        self.bytes_served = 0
        self.get_count = 0


class Handler(BaseHTTPRequestHandler):
    protocol_version = 'HTTP/1.1'

    def log_message(self, *args):
        pass

    def option(self, name, default=None):
        return self.query.get(name, [default])[0]

    def int_option(self, name, default=0):
        return int(self.option(name, default))

    def setup_request(self):
        parsed = urllib.parse.urlparse(self.path)
        self.query = urllib.parse.parse_qs(parsed.query, keep_blank_values=True)
        log = self.server.log
        with log.lock:
            log.ports.add(self.client_address[1])
            log.requests.append({
                'method': self.command,
                'path': parsed.path,
                'time': time.time(),
                'range': self.headers.get('Range'),
                'headers': {k.lower(): v for k, v in self.headers.items()},
            })

    def do_HEAD(self):
        self.setup_request()
        status = self.int_option('head_status', 0) or self.int_option('status', 200)
        self.send_response(status)
        self.send_common_headers()
        self.send_header('Connection', 'close')
        self.close_connection = True
        self.end_headers()

    def send_common_headers(self):
        size = self.int_option('size')
        if self.option('length', '1') == '1':
            self.send_header('Content-Length', str(size))
        if self.option('ranges', '1') == '1':
            self.send_header('Accept-Ranges', 'bytes')
        etag = self.option('etag')
        if etag:
            generation = self.server.etag_generation
            self.send_header('ETag', '"%s-%d"' % (etag, generation))
        disposition = self.option('cd')
        if disposition:
            self.send_header('Content-Disposition', disposition)

    def do_GET(self):
        self.setup_request()
        log = self.server.log
        with log.lock:
            log.get_count += 1
            attempt = log.get_count
            log.active_gets += 1
            log.max_active_gets = max(log.max_active_gets, log.active_gets)
        try:
            self.serve_get(attempt)
        finally:
            with log.lock:
                log.active_gets -= 1

    def serve_get(self, attempt):
        log = self.server.log
        status = self.int_option('status', 200)
        if status != 200:
            body = b'error page ' * 10
            self.send_response(status)
            self.send_header('Content-Length', str(len(body)))
            self.send_header('Connection', 'close')
            self.close_connection = True
            self.end_headers()
            self.wfile.write(body)
            return

        size = self.int_option('size')
        redirect = self.option('redirect')
        if redirect:
            self.send_response(302)
            self.send_header('Location', redirect)
            self.send_header('Content-Length', '0')
            self.end_headers()
            return

        start, end, partial = 0, size - 1, False
        requested = self.headers.get('Range')
        if requested and self.option('honour_range', '1') == '1':
            first, _, last = requested.split('=')[1].partition('-')
            start = int(first)
            end = int(last) if last else size - 1
            partial = True

        if size and start >= size:
            self.send_response(416)
            self.send_header('Content-Length', '0')
            self.end_headers()
            return

        length = max(0, end - start + 1)
        self.send_response(206 if partial else 200)
        if self.option('length', '1') == '1' or partial:
            self.send_header('Content-Length', str(length))
        if partial:
            self.send_header('Content-Range', 'bytes %d-%d/%d' % (start, end, size))
        if self.option('ranges', '1') == '1':
            self.send_header('Accept-Ranges', 'bytes')
        if self.option('length', '1') != '1' and not partial:
            self.send_header('Connection', 'close')
            self.close_connection = True
        self.end_headers()

        drop_first = self.int_option('drop_first_gets')
        drop_after = length // 2 if attempt <= drop_first else None
        delay = float(self.option('delay_per_mib', '0'))
        sent = 0
        while sent < length:
            take = min(256 * 1024, length - sent)
            if drop_after is not None and sent >= drop_after:
                self.close_connection = True
                self.connection.close()
                return
            try:
                self.wfile.write(content(start + sent, take))
            except OSError:
                return
            sent += take
            with log.lock:
                log.bytes_served += take
            if delay:
                time.sleep(delay * take / MIB)


class FakeSettings:
    def __init__(self, values):
        self.values = values

    def value(self, key, default=None):
        return self.values.get(key, default)

    def sync(self):
        pass


class FakeDatabase:
    def __init__(self):
        self.add_link = {}

    def updateDownloadTable(self, rows):
        pass

    def setDefaultGidInAddlinkTable(self, gid, **kwargs):
        pass

    def searchGidInAddLinkTable(self, gid):
        return dict(self.add_link)

    def updateAddLinkTable(self, rows):
        self.add_link.update(rows[0])


class FakeMainWindow:
    def __init__(self, settings):
        self.persepolis_setting = FakeSettings(settings)
        self.persepolis_db = FakeDatabase()
        self.download_sessions_list = []


class Environment:
    def __init__(self):
        self.server = ThreadingHTTPServer(('127.0.0.1', 0), Handler)
        self.server.daemon_threads = True
        self.server.etag_generation = 1
        self.reset()
        threading.Thread(target=self.server.serve_forever, daemon=True).start()
        self.folder = tempfile.mkdtemp(prefix='persepolis-observe-')

    def reset(self):
        self.server.log = Log()

    def url(self, name='file.bin', **query):
        return 'http://127.0.0.1:%d/%s?%s' % (
            self.server.server_address[1], name, urllib.parse.urlencode(query))

    def fresh_folder(self):
        shutil.rmtree(self.folder, ignore_errors=True)
        os.makedirs(self.folder)
        for name in ['Audios', 'Videos', 'Others', 'Documents', 'Compressed']:
            os.makedirs(os.path.join(self.folder, name))
        return self.folder

    def make_download(self, link, connections=64, settings=None, **options):
        values = {
            'settings/timeout': 5,
            'settings/max-tries': 5,
            'settings/retry-wait': 0,
            'settings/chunk-size': 100,
            'settings/dont-check-certificate': 'no',
            'settings/download_path': '/somewhere/else',
            'settings/subfolder': 'no',
        }
        values.update(settings or {})
        window = FakeMainWindow(values)
        request = {
            'link': link, 'out': None, 'download_path': self.folder, 'ip': None, 'port': None,
            'proxy_user': None, 'proxy_passwd': None, 'proxy_type': None, 'download_user': None,
            'download_passwd': None, 'header': None, 'user_agent': None, 'load_cookies': None,
            'referer': None, 'start_time': None, 'end_time': None, 'connections': connections,
        }
        request.update(options)
        return persepolis_lib_prime.Download(request, window, 'aaaaaaaaaaaaaaaa')


def run(download, limit=90, during=None):
    """Runs a download, returning how it ended, including any exception it died with."""
    outcome = {'exception': None}

    def body():
        try:
            download.start()
        except BaseException as error:
            outcome['exception'] = '%s: %s' % (type(error).__name__, error)

    started = time.time()
    thread = threading.Thread(target=body, daemon=True)
    thread.start()
    if during:
        during(download)
    thread.join(limit)
    outcome['hung'] = thread.is_alive()
    if outcome['hung']:
        download.downloadStop()
        thread.join(10)
    outcome['seconds'] = round(time.time() - started, 2)
    return outcome


def describe(env, download, outcome, size=None):
    log = env.server.log
    files = {}
    for root, _, names in os.walk(env.folder):
        for name in names:
            path = os.path.join(root, name)
            relative = os.path.relpath(path, env.folder)
            info = {'bytes': os.path.getsize(path)}
            if size is not None and not name.endswith('.persepolis'):
                with open(path, 'rb') as handle:
                    info['intact'] = hashlib.sha256(handle.read()).hexdigest() == expected_sha(size)
            files[relative] = info
    gets = [r for r in log.requests if r['method'] == 'GET']
    return {
        'status': download.download_status,
        'error_message': download.error_message,
        'parts': download.number_of_parts,
        'connections': download.number_of_threads,
        'file_name': download.file_name,
        'percent': download.download_percent,
        'downloaded_size': download.downloaded_size,
        'file_size': download.file_size,
        'heads': len(log.requests) - len(gets),
        'gets': len(gets),
        'max_simultaneous_gets': log.max_active_gets,
        'bytes_served': log.bytes_served,
        'files': files,
        **outcome,
    }


# Scenarios


def large_file(env):
    results = []
    size = 128 * MIB
    for _ in range(3):
        env.fresh_folder()
        env.reset()
        download = env.make_download(env.url(size=size))
        results.append(describe(env, download, run(download), size))
    return results


def small_file_few_connections(env):
    size = 10 * MIB
    env.fresh_folder()
    download = env.make_download(env.url(size=size), connections=4)
    return describe(env, download, run(download), size)


def no_range_support(env):
    size = 4 * MIB
    env.fresh_folder()
    download = env.make_download(env.url(size=size, ranges=0, honour_range=0), connections=64)
    return describe(env, download, run(download), size)


def no_content_length(env):
    size = 3 * MIB
    env.fresh_folder()
    download = env.make_download(env.url(size=size, length=0, ranges=0, honour_range=0))
    return describe(env, download, run(download), size)


def quoted_disposition(env):
    size = MIB
    env.fresh_folder()
    download = env.make_download(env.url(size=size, cd='attachment; filename="report.pdf"'))
    return describe(env, download, run(download), size)


def extended_disposition(env):
    size = MIB
    env.fresh_folder()
    download = env.make_download(env.url(size=size, cd="attachment; filename*=UTF-8''r%C3%A9sum%C3%A9.pdf"))
    return describe(env, download, run(download), size)


def dropped_connections(env):
    size = 2 * MIB
    env.fresh_folder()
    download = env.make_download(env.url(size=size, drop_first_gets=3), connections=1)
    return describe(env, download, run(download), size)


def always_503(env):
    results = {}
    for tries in [1, 2]:
        env.fresh_folder()
        env.reset()
        download = env.make_download(
            env.url(size=MIB, head_status=200, status=503), connections=1,
            settings={'settings/max-tries': tries})
        results['max_tries_%d' % tries] = describe(env, download, run(download))
    return results


def always_404(env):
    env.fresh_folder()
    download = env.make_download(env.url(size=MIB, status=404))
    return describe(env, download, run(download, limit=15))


def head_not_allowed(env):
    size = MIB
    env.fresh_folder()
    download = env.make_download(env.url(size=size, head_status=405))
    return describe(env, download, run(download), size)


def stop_partway(download):
    """Stops once every worker has started, which takes 0.1 s per Connection, and the control
    file has had time to be written."""
    time.sleep(5.5)
    download.downloadStop()


def stop_then_resume(env):
    size = 40 * MIB
    env.fresh_folder()
    link = env.url(size=size, etag='v', delay_per_mib=4)

    first = env.make_download(link)
    stopped = describe(env, first, run(first, during=stop_partway))
    control_path = os.path.join(env.folder, 'file.bin.persepolis')
    with open(control_path) as handle:
        control = json.load(handle)
    statuses = {}
    for part in control['download_infromation_list']:
        statuses[part[2]] = statuses.get(part[2], 0) + 1

    env.reset()
    second = env.make_download(link)
    resumed = describe(env, second, run(second), size)
    ranges = sorted(r['range'] for r in env.server.log.requests if r['method'] == 'GET')
    return {
        'after_stop': stopped,
        'control_keys': sorted(control),
        'control_etag': control['ETag'],
        'control_number_of_parts': control['number_of_parts'],
        'control_part_entries': len(control['download_infromation_list']),
        'control_part_statuses': statuses,
        'resume': resumed,
        'resume_ranges_sample': ranges[:4],
    }


def stop_before_first_control_write(env):
    size = 40 * MIB
    env.fresh_folder()
    link = env.url(size=size, etag='v', delay_per_mib=4)

    def stop_soon(download):
        time.sleep(1.5)
        download.downloadStop()

    first = env.make_download(link)
    run(first, during=stop_soon)
    control_bytes = os.path.getsize(os.path.join(env.folder, 'file.bin.persepolis'))
    downloaded_before_stop = first.downloaded_size

    env.reset()
    second = env.make_download(env.url(size=size, etag='v'))
    resumed = describe(env, second, run(second), size)
    return {
        'control_bytes_after_stop': control_bytes,
        'downloaded_before_stop': downloaded_before_stop,
        'second_run_bytes_served': resumed['bytes_served'],
        'second_run_status': resumed['status'],
        'files': resumed['files'],
    }


def etag_changes(env):
    size = 40 * MIB
    env.fresh_folder()
    link = env.url(size=size, etag='v', delay_per_mib=4)

    first = env.make_download(link)
    run(first, during=stop_partway)
    env.server.etag_generation = 2
    env.reset()
    second = env.make_download(env.url(size=size, etag='v'))
    result = describe(env, second, run(second), size)
    env.server.etag_generation = 1
    return result


def size_changes_without_etag(env):
    env.fresh_folder()
    link = env.url(size=40 * MIB, delay_per_mib=4)

    first = env.make_download(link)
    run(first, during=stop_partway)
    env.reset()
    second = env.make_download(env.url(size=30 * MIB))
    return describe(env, second, run(second), 30 * MIB)


def truly_concurrent(env):
    """Slow enough that workers overlap, which is when a shared Range header could go wrong."""
    results = []
    size = 64 * MIB
    for _ in range(3):
        env.fresh_folder()
        env.reset()
        download = env.make_download(env.url(size=size, delay_per_mib=8))
        described = describe(env, download, run(download), size)
        ranges = [r['range'] for r in env.server.log.requests if r['method'] == 'GET']
        results.append({
            'status': described['status'],
            'gets': described['gets'],
            'distinct_ranges': len(set(ranges)),
            'max_simultaneous_gets': described['max_simultaneous_gets'],
            'bytes_served': described['bytes_served'],
            'files': described['files'],
            'seconds': described['seconds'],
        })
    return results


def subfolders(env):
    results = {}
    settings = {'settings/download_path': env.folder, 'settings/subfolder': 'yes'}
    for name in ['song.MP3', 'clip.mkv', 'book.pdf', 'book.mobi', 'book.pub', 'data.zip', 'old.Z', 'noext']:
        env.fresh_folder()
        env.reset()
        download = env.make_download(env.url(name=name, size=MIB), settings=settings)
        results[name] = describe(env, download, run(download))['files']
    return results


def collision_names(env):
    results = {}
    settings = {'settings/download_path': env.folder, 'settings/subfolder': 'yes'}
    for existing, name in [(['Others/x.bin'], 'x.bin'),
                           (['Others/x_1.bin'], 'x_1.bin'),
                           (['Others/long.bin'], 'long.bin'),
                           (['Others/long.bin', 'Others/long_1.bin'], 'long.bin'),
                           (['Others/long_9.bin'], 'long_9.bin'),
                           (['Others/noext'], 'noext'),
                           (['Compressed/a.zip'], 'a.zip')]:
        env.fresh_folder()
        env.reset()
        for path in existing:
            open(os.path.join(env.folder, path), 'w').close()
        download = env.make_download(env.url(name=name, size=MIB), settings=settings)
        outcome = describe(env, download, run(download, limit=15))
        results['%s then %s' % (existing, name)] = {
            'files': sorted(outcome['files']), 'exception': outcome['exception'], 'hung': outcome['hung'],
        }
    return results


def authenticated_proxy(env):
    env.fresh_folder()
    download = env.make_download(
        env.url(size=MIB), ip='127.0.0.1', port=9, proxy_user='me', proxy_passwd='pw', proxy_type='http')
    result = run(download, limit=30)
    return {
        'proxies': dict(download.requests_session.proxies),
        'status': download.download_status,
        'error_message': download.error_message,
        **result,
    }


def request_headers(env):
    size = MIB
    env.fresh_folder()
    cookies = os.path.join(env.folder, 'cookies.txt')
    with open(cookies, 'w') as handle:
        handle.write('# Netscape HTTP Cookie File\n')
        handle.write('127.0.0.1\tFALSE\t/\tFALSE\t0\tvisible\tyes\n')
        handle.write('#HttpOnly_127.0.0.1\tFALSE\t/\tFALSE\t0\thttponly\tyes\n')
        handle.write('other.example\tFALSE\t/\tFALSE\t0\telsewhere\tno\n')
    download = env.make_download(
        env.url(size=size), connections=1, download_user='me', download_passwd='pw',
        referer='https://referer.example/', user_agent='Observer/1', header='X-One: 1\nX-Two: two words',
        load_cookies=cookies)
    described = describe(env, download, run(download))
    gets = [r for r in env.server.log.requests if r['method'] == 'GET']
    heads = [r for r in env.server.log.requests if r['method'] == 'HEAD']
    keep = ['authorization', 'referer', 'user-agent', 'x-one', 'x-two', 'cookie', 'range']
    return {
        'status': described['status'],
        'basic_auth_expected': 'Basic ' + base64.b64encode(b'me:pw').decode(),
        'head': {k: heads[0]['headers'].get(k) for k in keep},
        'get': {k: gets[0]['headers'].get(k) for k in keep},
    }


def default_user_agent(env):
    env.fresh_folder()
    download = env.make_download(env.url(size=MIB), connections=1)
    run(download)
    return env.server.log.requests[0]['headers'].get('user-agent')


def cross_host_redirect(env):
    env.fresh_folder()
    port = env.server.server_address[1]
    target = 'http://localhost:%d/file.bin?size=%d' % (port, MIB)
    download = env.make_download(
        env.url(size=MIB, redirect=target), connections=1, download_user='me', download_passwd='pw')
    described = describe(env, download, run(download, limit=30), MIB)
    gets = [r for r in env.server.log.requests if r['method'] == 'GET']
    return {
        'status': described['status'],
        'files': described['files'],
        'authorization_on_each_get': [g['headers'].get('authorization') for g in gets],
    }


def empty_file(env):
    env.fresh_folder()
    download = env.make_download(env.url(size=0))
    return describe(env, download, run(download, limit=30))


def speed_dial(env):
    results = {}
    size = 16 * MIB
    for dial in [0, 5, 9]:
        for connections in [16, 4]:
            env.fresh_folder()
            env.reset()
            download = env.make_download(env.url(size=size), connections=connections)
            download.limitSpeed(dial)
            outcome = run(download, limit=60)
            results['dial_%d_connections_%d' % (dial, connections)] = {
                'seconds': outcome['seconds'],
                'mib_per_second': round(16 / outcome['seconds'], 2),
                'effective_connections': download.number_of_threads,
                'status': download.download_status,
            }
    return results


SCENARIOS = [
    large_file, small_file_few_connections, no_range_support, no_content_length, quoted_disposition,
    extended_disposition, dropped_connections, always_503, always_404, head_not_allowed,
    stop_then_resume, stop_before_first_control_write, etag_changes, size_changes_without_etag,
    truly_concurrent, subfolders, collision_names, authenticated_proxy, request_headers,
    default_user_agent, cross_host_redirect, empty_file, speed_dial,
]


def main():
    wanted = sys.argv[1:]
    if not os.environ.get('HOME', '').startswith(tempfile.gettempdir().rsplit('/', 1)[0]):
        raise SystemExit('Set HOME to a temporary folder, so Persepolis leaves your real config alone.')
    env = Environment()
    results = {}
    for scenario in SCENARIOS:
        if wanted and scenario.__name__ not in wanted:
            continue
        env.reset()
        started = time.time()
        try:
            results[scenario.__name__] = scenario(env)
        except BaseException as error:
            results[scenario.__name__] = {'scenario_failed': '%s: %s' % (type(error).__name__, error)}
        print('finished %s in %.1fs' % (scenario.__name__, time.time() - started), file=sys.stderr)
    print(json.dumps(results, indent=2, default=str))
    shutil.rmtree(env.folder, ignore_errors=True)


if __name__ == '__main__':
    main()
