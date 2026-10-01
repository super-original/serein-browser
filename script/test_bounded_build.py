import os
import pathlib
import sys
import tempfile
import unittest
from unittest import mock
import threading
import bounded_build
from bounded_build import GIB, descendants, limit_reason, parse_processes, run_bounded

class BoundedBuildTests(unittest.TestCase):
    def test_process_tree_excludes_unrelated_compiler_and_accepts_spaces(self):
        rows=parse_processes('10 1 30 /usr/bin/git\n11 10 40 /a path/clang\n12 11 50 compiler\n99 1 100 clang\nbad row\n')
        owned=descendants(rows,10)
        self.assertEqual([p['pid'] for p in owned],[10,11,12])
        self.assertEqual(sum(p['rss_bytes'] for p in owned),120*1024)
        self.assertEqual(owned[1]['executable'],'/a path/clang')

    def test_resource_and_time_stops_are_distinct(self):
        sample=dict(disk_free_bytes=10*GIB,descendant_rss_bytes=GIB,system_free_memory_percent=None)
        self.assertIsNone(limit_reason(sample,1,10))
        self.assertEqual(limit_reason(sample,10,10),'elapsed-time-limit')
        self.assertEqual(limit_reason(dict(sample,disk_free_bytes=7*GIB),1,10),'disk-reserve-limit')
        self.assertEqual(limit_reason(dict(sample,descendant_rss_bytes=6*GIB),1,10),'sampled-process-rss-limit')
        self.assertEqual(limit_reason(dict(sample,system_free_memory_percent=7),1,10),'system-memory-pressure-limit')

    def test_limit_reaps_owned_process_without_signalling_parent(self):
        parent=os.getpid()
        with tempfile.TemporaryDirectory() as root:
            def sample(directory,pid):
                self.assertNotEqual(pid,parent)
                return dict(disk_free_bytes=7*GIB,descendant_rss_bytes=0,system_free_memory_percent=None)
            result=run_bounded([sys.executable,'-c','import time;time.sleep(60)'],cwd=root,evidence=root,name='bounded',seconds=30,sample_fn=sample,interval=0.01)
            self.assertEqual(result['stop_reason'],'disk-reserve-limit')
            self.assertIsNotNone(result['returncode'])
            self.assertTrue(pathlib.Path(root,'bounded-summary.json').is_file())
            self.assertEqual(os.getpid(),parent)

    def test_success_preserves_output_and_exit_status(self):
        with tempfile.TemporaryDirectory() as root:
            sample=lambda directory,pid:dict(disk_free_bytes=10*GIB,descendant_rss_bytes=0,system_free_memory_percent=None)
            result=run_bounded([sys.executable,'-c','print("bounded output")'],cwd=root,evidence=root,name='success',seconds=10,sample_fn=sample,interval=0.01)
            self.assertEqual(result['returncode'],0);self.assertIsNone(result['stop_reason'])
            self.assertEqual(pathlib.Path(root,'success.log').read_text().strip(),'bounded output')

    def test_shutdown_wakeup_drains_bytes_arriving_after_eagain(self):
        with tempfile.TemporaryDirectory() as root:
            real_event=threading.Event
            class WakeupEvent:
                def __init__(self):self.event=real_event()
                def is_set(self):return self.event.is_set()
                def set(self):self.event.set()
                def wait(self,seconds):return self.event.wait(5)
            # First read sees an empty pipe; the child exits while the reader
            # waits. Shutdown must attempt the second read before closing it.
            real_read=os.read
            reads=iter([BlockingIOError(),b'late output\n',b''])
            def read(*args):
                if threading.current_thread() is threading.main_thread():return real_read(*args)
                value=next(reads)
                if isinstance(value,Exception):raise value
                return value
            sample=lambda directory,pid:dict(disk_free_bytes=10*GIB,descendant_rss_bytes=0,system_free_memory_percent=None)
            with mock.patch.object(bounded_build.os,'read',side_effect=read), mock.patch.object(bounded_build,'Event',WakeupEvent):
                result=run_bounded([sys.executable,'-c','pass'],cwd=root,evidence=root,name='late',seconds=10,sample_fn=sample,interval=0.01)
            self.assertEqual(result['returncode'],0)
            self.assertEqual(pathlib.Path(root,'late.log').read_bytes(),b'late output\n')

if __name__=='__main__':unittest.main()
