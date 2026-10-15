#!/usr/bin/env python3
"""Integration checks using disposable local processes; never opens a tunnel."""
import json
import os
from pathlib import Path
import select
import signal
import subprocess
import sys
import time
import unittest

GUARDIAN = str(Path(sys.argv.pop(1)).resolve())


def wait_gone(pid, timeout=7):
    deadline = time.monotonic() + timeout
    while time.monotonic() < deadline:
        try:
            os.kill(pid, 0)
        except ProcessLookupError:
            return
        time.sleep(0.05)
    raise AssertionError(f"Disposable process {pid} survived guardian cleanup")


def read_line(handle):
    if not select.select([handle], [], [], 8)[0]:
        raise AssertionError("Timed out waiting for fixture readiness")
    line = handle.readline()
    if not line:
        raise AssertionError("Fixture exited before readiness")
    return line


class GuardianTests(unittest.TestCase):
    def test_closed_lifetime_pipe_stops_child(self):
        child = subprocess.Popen([GUARDIAN, '/bin/sh', '-c', 'echo $$; exec /bin/sleep 120'],
                                 stdin=subprocess.PIPE, stdout=subprocess.PIPE, text=True)
        try:
            pid = int(read_line(child.stdout))
            child.stdin.close()
            child.wait(timeout=7)
            wait_gone(pid)
        finally:
            if child.poll() is None:
                child.kill()
                child.wait()
            child.stdout.close()

    def test_sigkill_of_parent_stops_connector(self):
        parent_code = '''
import json, signal, subprocess, sys
child = subprocess.Popen([sys.argv[1], '/bin/sh', '-c', 'echo $$; exec /bin/sleep 120'],
                         stdin=subprocess.PIPE, stdout=subprocess.PIPE, text=True)
pid = int(child.stdout.readline())
print(json.dumps([child.pid, pid]), flush=True)
while True: signal.pause()
'''
        parent = subprocess.Popen([sys.executable, '-c', parent_code, GUARDIAN],
                                  stdout=subprocess.PIPE, text=True)
        owned = []
        try:
            owned = json.loads(read_line(parent.stdout))
            parent.kill()
            parent.wait(timeout=3)
            while owned:
                wait_gone(owned[0])
                owned.pop(0)
        finally:
            if parent.poll() is None:
                parent.kill()
                parent.wait()
            for pid in owned:
                try:
                    os.kill(pid, signal.SIGKILL)
                except ProcessLookupError:
                    pass
            parent.stdout.close()

    def test_stubborn_child_is_killed_after_grace_period(self):
        child = subprocess.Popen([GUARDIAN, '/bin/sh', '-c', "trap '' TERM; echo $$; while :; do /bin/sleep 1; done"],
                                 stdin=subprocess.PIPE, stdout=subprocess.PIPE, text=True)
        try:
            pid = int(read_line(child.stdout))
            start = time.monotonic()
            child.stdin.close()
            child.wait(timeout=7)
            self.assertGreaterEqual(time.monotonic() - start, 2.5)
            wait_gone(pid)
        finally:
            if child.poll() is None:
                child.kill()
                child.wait()
            child.stdout.close()


if __name__ == '__main__':
    unittest.main()
