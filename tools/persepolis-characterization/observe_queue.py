"""Runs Persepolis's real Queue thread, engine and database against a local server, and records what
they do. The main window is faked, including the thread that copies live status into the database.

Usage is the same as observe_http_engine.py, and HOME must be a temporary folder for the same reason.
Clock-time scenarios wait for real minutes, so the whole run takes several minutes.
"""

import datetime
import json
import os
import shutil
import sys
import tempfile
import threading
import time

from PySide6.QtCore import QCoreApplication, Qt

from observe_http_engine import MIB, Environment, FakeSettings
from persepolis.scripts.data_base import PersepolisDB, TempDB
from persepolis.scripts.queue import Queue


class Widget:
    """Stands in for the check boxes and dial the Queue thread reads from the window."""

    def __init__(self, checked=False, value=10):
        self.checked = checked
        self.dial = value
        self.set_calls = []

    def isChecked(self):
        return self.checked

    def setChecked(self, value):
        self.checked = value
        self.set_calls.append(value)

    def value(self):
        return self.dial


class FakeIndex:
    def data(self):
        return 'nothing selected'


class FakeTree:
    def currentIndex(self):
        return FakeIndex()


class Window:
    def __init__(self, folder, settings=None):
        values = {
            'settings/timeout': 5,
            'settings/max-tries': 5,
            'settings/retry-wait': 0,
            'settings/chunk-size': 100,
            'settings/dont-check-certificate': 'no',
            'settings/download_path': '/somewhere/else',
            'settings/subfolder': 'no',
            'settings/wait-queue': [0, 0],
        }
        values.update(settings or {})
        self.persepolis_setting = FakeSettings(values)
        self.persepolis_db = PersepolisDB()
        self.persepolis_db.createTables()
        self.persepolis_db.resetDataBase()
        self.temp_db = TempDB()
        self.temp_db.createTables()
        self.download_sessions_list = []
        self.threadPool = []
        self.all_video_finder_gid_list = []
        self.video_finder_threads_dict = {}
        self.single_video_link_gid_list = []
        self.reverse_checkBox = Widget()
        self.limit_dial = Widget(value=10)
        self.after_checkBox = Widget()
        self.category_tree = FakeTree()
        self.folder = folder
        self.running = True
        threading.Thread(target=self.poll, daemon=True).start()

    def poll(self):
        """What CheckDownloadInfoThread does: copies live status into the database."""
        counter = 0
        while self.running:
            time.sleep(0.2)
            statuses = []
            write_it = 0
            for session in list(self.download_sessions_list):
                statuses.append(session['download_session'].tellStatus())
                if session['download_session'].write_it_to_the_database is False:
                    session['download_session'].write_it_to_the_database = True
                    write_it += 1
            if counter == 4 or write_it:
                self.persepolis_db.updateDownloadTable(statuses)
                counter = -1
            counter += 1

    def add(self, gid, link, name, category='Scheduled Downloads', status='stopped', connections=1):
        date = '2026/11/03 , 00:00:00'
        self.persepolis_db.insertInDownloadTable([{
            'file_name': name, 'status': status, 'size': '***', 'downloaded_size': '***', 'percent': '***',
            'connections': '***', 'rate': '***', 'estimate_time_left': '***', 'gid': gid, 'link': link,
            'first_try_date': date, 'last_try_date': date, 'category': category,
        }])
        self.persepolis_db.insertInAddLinkTable([{
            'gid': gid, 'out': name, 'start_time': None, 'end_time': None, 'link': link, 'ip': None, 'port': None,
            'proxy_user': None, 'proxy_passwd': None, 'download_user': None, 'download_passwd': None,
            'connections': connections, 'limit_value': 10, 'download_path': self.folder, 'referer': None,
            'load_cookies': None, 'user_agent': None, 'header': None, 'after_download': None, 'proxy_type': None,
        }])

    def status(self, gid):
        return self.persepolis_db.searchGidInDownloadTable(gid)['status']


class Run:
    def __init__(self, env, settings=None, start_time=None, end_time=None, category='Scheduled Downloads'):
        env.fresh_folder()
        env.reset()
        self.env = env
        self.window = Window(env.folder, settings)
        self.category = category
        self.start_time = start_time
        self.end_time = end_time
        self.notifications = []
        self.started_at = None
        self.queue = None

    def start(self):
        self.window.temp_db.insertInQueueTable(self.category)
        self.queue = Queue(self.category, self.start_time, self.end_time, self.window)
        # Direct, because nothing runs an event loop here to deliver a queued signal.
        self.queue.NOTIFYSENDSIGNAL.connect(self.record_notification, Qt.DirectConnection)
        self.started_at = time.time()
        self.queue.start()
        time.sleep(0.3)

    def record_notification(self, message):
        self.notifications.append(message[1])

    def wait(self, limit=240):
        deadline = time.time() + limit
        while not self.queue.isFinished() and time.time() < deadline:
            time.sleep(0.1)
        return self.queue.isFinished()

    def requests(self):
        return [r for r in self.env.server.log.requests if r['method'] == 'GET']

    def order(self):
        names = []
        for request in self.requests():
            name = request['path'].strip('/')
            if not names or names[-1] != name:
                names.append(name)
        return names

    def finish(self):
        self.window.running = False
        for session in list(self.window.download_sessions_list):
            session['download_session'].downloadStop()
        time.sleep(0.5)


def file_url(env, name, **query):
    query.setdefault('size', MIB)
    query.setdefault('delay_per_mib', 1)
    return env.url(name=name, **query)


def add_files(run, names, **query):
    """Adds files oldest first, as if the user added them in this order."""
    for index, name in enumerate(names):
        gid = '%016x' % (0x1000000000000000 + index + 1)
        run.window.add(gid, file_url(run.env, name, **query), name)
    return ['%016x' % (0x1000000000000000 + index + 1) for index in range(len(names))]


def clock_after(seconds):
    """The H:M form Persepolis stores, and the moment that minute begins."""
    moment = datetime.datetime.now() + datetime.timedelta(seconds=seconds)
    moment = moment.replace(second=0, microsecond=0)
    return moment.strftime('%H:%M'), moment.timestamp()


# Scenarios


def order_default(env):
    run = Run(env)
    add_files(run, ['a', 'b', 'c'])
    run.start()
    finished = run.wait()
    result = {
        'order': run.order(),
        'max_simultaneous_gets': env.server.log.max_active_gets,
        'finished': finished,
        'notifications': run.notifications,
        'seconds': round(time.time() - run.started_at, 1),
    }
    run.finish()
    return result


def order_reversed(env):
    run = Run(env)
    add_files(run, ['a', 'b', 'c'])
    run.window.reverse_checkBox.checked = True
    run.start()
    run.wait()
    result = {'order': run.order(), 'notifications': run.notifications}
    run.finish()
    return result


def failure_is_retried_by_passes(env):
    run = Run(env, settings={'settings/max-tries': 0})
    run.window.add('1000000000000001', file_url(env, 'a'), 'a')
    run.window.add('1000000000000002', file_url(env, 'b', head_status=200, status=503), 'b')
    run.window.add('1000000000000003', file_url(env, 'c'), 'c')
    run.start()
    finished = run.wait()
    gets = [r['path'].strip('/') for r in run.requests()]
    result = {
        'gets_in_order': gets,
        'finished': finished,
        'statuses': {name: run.window.status(gid) for name, gid in
                     [('a', '1000000000000001'), ('b', '1000000000000002'), ('c', '1000000000000003')]},
        'notifications': run.notifications,
        'seconds': round(time.time() - run.started_at, 1),
    }
    run.finish()
    return result


def added_while_running(env):
    run = Run(env)
    add_files(run, ['a'], size=3 * MIB, delay_per_mib=2)
    run.start()
    time.sleep(1)
    run.window.add('1000000000000009', file_url(env, 'late'), 'late')
    run.wait()
    result = {'order': run.order(), 'notifications': run.notifications}
    run.finish()
    return result


def stopped_by_user(env):
    run = Run(env)
    gids = add_files(run, ['a', 'b', 'c'], size=64 * MIB, delay_per_mib=2)
    run.start()
    time.sleep(5)
    run.queue.start = False
    run.queue.stop = True
    finished = run.wait(30)
    result = {
        'order': run.order(),
        'finished': finished,
        'statuses': {gid[-1]: run.window.status(gid) for gid in gids},
        'notifications': run.notifications,
        'seconds_after_stop': round(time.time() - run.started_at - 5, 1),
    }
    run.finish()
    return result


def already_complete_is_skipped(env):
    run = Run(env)
    run.window.add('1000000000000001', file_url(env, 'a'), 'a')
    run.window.add('1000000000000002', file_url(env, 'b'), 'b', status='complete')
    run.start()
    run.wait()
    result = {'order': run.order(), 'notifications': run.notifications}
    run.finish()
    return result


def empty_queue(env):
    run = Run(env)
    run.start()
    finished = run.wait(30)
    result = {'finished': finished, 'notifications': run.notifications,
              'seconds': round(time.time() - run.started_at, 1)}
    run.finish()
    return result


def fast_files(env):
    """Fast enough to hit D19, the false error, so Passes fetch them again."""
    run = Run(env)
    gids = add_files(run, ['a', 'b'], delay_per_mib=0)
    run.start()
    run.wait()
    result = {
        'gets_in_order': [r['path'].strip('/') for r in run.requests()],
        'statuses': {gid[-1]: run.window.status(gid) for gid in gids},
        'notifications': run.notifications,
        'files': sorted(os.listdir(env.folder)),
    }
    run.finish()
    return result


def start_time_goes_to_first_unfinished(env):
    text, moment = clock_after(70)
    run = Run(env, start_time=text)
    run.window.add('1000000000000001', file_url(env, 'a'), 'a')
    run.window.add('1000000000000002', file_url(env, 'b'), 'b')
    run.window.add('1000000000000003', file_url(env, 'c'), 'c', status='complete')
    run.start()
    time.sleep(6)
    before = {
        'b_status': run.window.status('1000000000000002'),
        'a_status': run.window.status('1000000000000001'),
        'b_start_time': run.window.persepolis_db.searchGidInAddLinkTable('1000000000000002')['start_time'],
        'a_start_time': run.window.persepolis_db.searchGidInAddLinkTable('1000000000000001')['start_time'],
        'gets': len(run.requests()),
    }
    run.wait()
    gets = run.requests()
    result = {
        'before_the_time': before,
        'order': run.order(),
        'first_get_seconds_after_the_minute_began': round(gets[0]['time'] - moment, 1),
        'b_start_time_after': run.window.persepolis_db.searchGidInAddLinkTable('1000000000000002')['start_time'],
        'notifications': run.notifications,
    }
    run.finish()
    return result


def end_time_stops_the_queue(env):
    text, moment = clock_after(70)
    run = Run(env, end_time=text)
    # Slow, but never so slow that a pause trips the 5 second timeout.
    gids = add_files(run, ['a', 'b'], size=128 * MIB, delay_per_mib=2)
    run.start()
    time.sleep(5)
    end_times = {gid[-1]: run.window.persepolis_db.searchGidInAddLinkTable(gid)['end_time'] for gid in gids}
    finished = run.wait(150)
    result = {
        'end_times_while_running': end_times,
        'order': run.order(),
        'finished': finished,
        'statuses': {gid[-1]: run.window.status(gid) for gid in gids},
        'queue_finished_seconds_after_the_minute_began': round(time.time() - moment, 1),
        'notifications': run.notifications,
    }
    run.finish()
    return result


def finishing_before_the_end_time(env):
    """D2: what happens to a Download that finishes while its End time is still ahead."""
    text, moment = clock_after(70)
    run = Run(env, end_time=text)
    gids = add_files(run, ['a'], delay_per_mib=4)
    run.start()
    run.wait(60)
    time.sleep(1)
    before = run.window.status(gids[0])
    queue_finished_before_end = run.queue.isFinished()
    sessions_before = len(run.window.download_sessions_list)
    time.sleep(max(0, moment - time.time()) + 8)
    result = {
        'status_after_queue_finished': before,
        'queue_finished_before_end_time': queue_finished_before_end,
        'sessions_left_after_queue_finished': sessions_before,
        'status_after_end_time': run.window.status(gids[0]),
        'sessions_left_after_end_time': len(run.window.download_sessions_list),
        'files': sorted(os.listdir(env.folder)),
        'notifications': run.notifications,
    }
    run.finish()
    return result


def queue_wait(env):
    run = Run(env, settings={'settings/wait-queue': [0, 1]})
    add_files(run, ['a', 'b'])
    run.start()
    run.wait(200)
    gets = run.requests()
    first_finished = gets[0]['time'] + 1
    result = {
        'order': run.order(),
        'seconds_between_first_get_and_second': round(gets[1]['time'] - gets[0]['time'], 1),
        'second_get_second_of_minute': datetime.datetime.fromtimestamp(gets[1]['time']).second,
        'first_get_clock': datetime.datetime.fromtimestamp(gets[0]['time']).strftime('%H:%M:%S'),
        'second_get_clock': datetime.datetime.fromtimestamp(gets[1]['time']).strftime('%H:%M:%S'),
        'first_finished_about': datetime.datetime.fromtimestamp(first_finished).strftime('%H:%M:%S'),
        'notifications': run.notifications,
    }
    run.finish()
    return result


def reverse_read_live(env):
    """D9: the Queue reads Reverse from the widget, so a change shows on the next Pass."""
    run = Run(env, settings={'settings/max-tries': 0})
    add_files(run, ['a', 'b'], head_status=200, status=503)
    run.start()
    while len(run.requests()) < 2:
        time.sleep(0.1)
    run.window.reverse_checkBox.checked = True
    run.wait()
    result = {'gets_in_order': [r['path'].strip('/') for r in run.requests()]}
    run.finish()
    return result


def speed_dial_read_live(env):
    run = Run(env)
    add_files(run, ['a'], size=64 * MIB, delay_per_mib=2)
    run.window.limit_dial.dial = 5
    run.start()
    time.sleep(4)
    session = run.window.download_sessions_list[0]['download_session']
    at_start = session.sleep_for_speed_limiting
    run.window.limit_dial.dial = 0
    run.queue.limit_changed = True
    time.sleep(2)
    after_change = session.sleep_for_speed_limiting
    run.queue.start = False
    run.queue.stop = True
    run.wait(30)
    result = {'sleep_at_start': at_start, 'sleep_after_change': after_change}
    run.finish()
    return result


def shutdown_on_completion(env):
    run = Run(env)
    add_files(run, ['a'], delay_per_mib=3)
    run.start()
    run.queue.after = True
    run.wait()
    result = {
        'shutdown_value': run.window.temp_db.returnCategory(run.category)['shutdown'],
        'notifications': run.notifications,
    }
    run.finish()
    return result


def shutdown_cancelled_by_stopping(env):
    run = Run(env)
    add_files(run, ['a'], size=64 * MIB, delay_per_mib=2)
    run.start()
    run.queue.after = True
    time.sleep(4)
    run.queue.start = False
    run.queue.stop = True
    run.wait(30)
    result = {
        'after_check_box_set_to': run.window.after_checkBox.set_calls,
        'shutdown_value': run.window.temp_db.returnCategory(run.category)['shutdown'],
        'notifications': run.notifications,
    }
    run.finish()
    return result


SCENARIOS = [
    order_default, order_reversed, failure_is_retried_by_passes, added_while_running, stopped_by_user,
    already_complete_is_skipped, empty_queue, fast_files, reverse_read_live, speed_dial_read_live,
    shutdown_on_completion, shutdown_cancelled_by_stopping, start_time_goes_to_first_unfinished,
    end_time_stops_the_queue, finishing_before_the_end_time, queue_wait,
]


def main():
    wanted = sys.argv[1:]
    if not os.environ.get('HOME', '').startswith(tempfile.gettempdir().rsplit('/', 1)[0]):
        raise SystemExit('Set HOME to a temporary folder, so Persepolis leaves your real config alone.')
    application = QCoreApplication(sys.argv)
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
        print('finished %s in %.1fs' % (scenario.__name__, time.time() - started), file=sys.stderr, flush=True)
    print(json.dumps(results, indent=2, default=str), flush=True)
    shutil.rmtree(env.folder, ignore_errors=True)
    del application
    os._exit(0)


if __name__ == '__main__':
    main()
