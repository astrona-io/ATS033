#!/usr/bin/env python3
"""Keep infrastructure errors out of the unfinished-lab evidence."""
import importlib.util
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch

sys.dont_write_bytecode = True

ROOT = Path(__file__).resolve().parents[2]
CHECKS = sorted(ROOT.glob('sections/section-*/module-*/labs/*/testing/check.py'))


class GradingTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        spec = importlib.util.spec_from_file_location('grader', CHECKS[0])
        cls.grader = importlib.util.module_from_spec(spec)
        with patch.object(sys, 'argv', [str(CHECKS[0])]):
            spec.loader.exec_module(cls.grader)

    def test_shared_helpers_do_not_drift(self):
        for filename in ('check.py', 'verify-start.sh', 'wait-solved.sh'):
            expected = (CHECKS[0].parent / filename).read_bytes()
            for check in CHECKS:
                self.assertEqual((check.parent / filename).read_bytes(), expected, str(check))

    def test_absent_resource_is_a_grading_failure(self):
        result = subprocess.CompletedProcess([], 0, '', '')
        with patch.object(self.grader, 'command', return_value=result) as command:
            with self.assertRaisesRegex(AssertionError, 'Missing configmap report'):
                self.grader.get('configmap', 'report')
        self.assertIn('--ignore-not-found', command.call_args.args[0])

    def test_api_error_is_not_a_missing_resource(self):
        result = subprocess.CompletedProcess([], 1, '', 'connection refused')
        with patch.object(self.grader, 'command', return_value=result):
            with self.assertRaisesRegex(RuntimeError, 'connection refused'):
                self.grader.get('configmap', 'report')

    def test_live_resource_is_decoded(self):
        result = subprocess.CompletedProcess([], 0, '{"data":{"actor":"observed"}}', '')
        with patch.object(self.grader, 'command', return_value=result):
            self.assertEqual(self.grader.get('configmap', 'report')['data']['actor'], 'observed')

    def test_missing_executable_is_an_error(self):
        with tempfile.TemporaryDirectory() as empty:
            result = subprocess.run([sys.executable, str(CHECKS[0])],
                                    env={'PATH': empty}, text=True, capture_output=True)
        self.assertEqual(result.returncode, 2, result.stdout + result.stderr)
        self.assertTrue(result.stdout.startswith('ERROR:'), result.stdout)

    def run_start_check(self, body):
        with tempfile.TemporaryDirectory() as directory:
            lab = Path(directory)
            (lab / 'testing').mkdir()
            (lab / 'validation').mkdir()
            start = lab / 'testing/verify-start.sh'
            shutil.copyfile(CHECKS[0].parent / 'verify-start.sh', start)
            (lab / 'validation/validate-outcome.sh').write_text('#!/bin/sh\n' + body)
            return subprocess.run(['bash', str(start)], text=True, capture_output=True)

    def test_start_accepts_deliberate_failure(self):
        result = self.run_start_check('echo "FAIL: Missing configmap report"\nexit 1\n')
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)

    def test_start_rejects_success_error_and_unknown_outcome(self):
        for body in ('echo "PASS: outcome"\nexit 0\n',
                     'echo "ERROR: connection refused"\nexit 2\n',
                     'echo "FAIL: Unknown outcome: wrong-name"\nexit 1\n',
                     'echo "FAIL: misleading text"\nexit 2\n',
                     'echo "Traceback: grader crashed"\nexit 1\n'):
            with self.subTest(body=body):
                self.assertNotEqual(self.run_start_check(body).returncode, 0)


if __name__ == '__main__':
    unittest.main()
