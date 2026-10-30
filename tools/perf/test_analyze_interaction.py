"""Deterministic checks for performance evidence calculations (no device needed)."""
import json
import pathlib
import tempfile
import unittest

from analyze_interaction import analyze


class AnalyzerTest(unittest.TestCase):
    def test_bounded_runtime_and_duplicate_present_samples(self):
        with tempfile.TemporaryDirectory() as tmp:
            root=pathlib.Path(tmp)
            (root/'metadata.json').write_text('{}')
            (root/'action.txt').write_text('BEGIN uptimeMs=1000\nEND uptimeMs=1200\n')
            (root/'threads.txt').write_text('u0_a1 10 10 1 0 0 0 0 S launcher\n')
            state='UNI_STATE='+json.dumps({'flutterViewport':{'page':0},'mapViews':[]})
            for file in ['before-state.txt','after-state.txt']:(root/file).write_text(state)
            (root/'interaction.ftrace').write_text(
                ' idle-0 (-----) [000] d..3 0.950000: sched_switch: prev_comm=idle prev_pid=0 prev_prio=120 prev_state=S ==> next_comm=launcher next_pid=10 next_prio=120\n'
                ' launcher-10 (10) [000] ...1 1.020000: tracing_mark_write: B|10|test\n'
                ' launcher-10 (10) [000] ...1 1.040000: tracing_mark_write: E\n'
                ' launcher-10 (10) [000] d..3 1.100000: sched_switch: prev_comm=launcher prev_pid=10 prev_prio=120 prev_state=S ==> next_comm=idle next_pid=0 next_prio=120\n'
                ' idle-0 (-----) [000] d..3 1.300000: sched_switch: prev_comm=idle prev_pid=0 prev_prio=120 prev_state=S ==> next_comm=launcher next_pid=10 next_prio=120\n')
            raw='16666666\n0 1020000000 0\n0 1040000000 0\n0 1060000000 0\n0 900000000 0\n'
            (root/'latency.json').write_text(json.dumps({'launcher':raw+raw}))
            result=analyze(root)
            self.assertTrue(result['traceCoversAction'])
            self.assertEqual(result['unparsedLines'],0)
            self.assertEqual(result['processCpu'][0]['cpuPercent'],50.0)
            self.assertEqual(result['layers']['launcher']['presentedInWindow'],3)
            self.assertEqual(result['layers']['launcher']['intervalMs']['mean'],20.0)
            self.assertEqual(result['slices'][0]['durationMs']['mean'],20.0)


if __name__=='__main__':unittest.main()
