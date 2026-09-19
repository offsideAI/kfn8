import importlib.util
import subprocess
import unittest
from pathlib import Path

SCRIPT = Path(__file__).resolve().parents[1] / 'tools/check_m0_readiness.py'

class ReadinessTests(unittest.TestCase):
    def setUp(self):
        self.assertTrue(SCRIPT.exists(), 'Readiness implementation does not exist yet')
        spec = importlib.util.spec_from_file_location('readiness', SCRIPT)
        self.module = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(self.module)

    def run_probe(self, responses):
        calls = []
        def runner(argv, **kwargs):
            calls.append((argv, kwargs))
            value = responses[len(calls)-1]
            if isinstance(value, Exception):
                raise value
            return subprocess.CompletedProcess(argv, value[0], value[1], '')
        report = self.module.probe('/example/Xcode27/Contents/Developer', runner=runner)
        return report, calls

    def test_ready_toolchain_never_claims_device_validation(self):
        report, calls = self.run_probe([(0, 'Xcode 27.0\nBuild version 27A266a'), (0, '-sdk xros27.0\n-sdk xrsimulator27.0'), (0, 'Apple Swift version 6.3')])
        self.assertEqual(report['status'], 'toolchain_ready_device_unverified')
        self.assertFalse(report['m0_passed'])
        self.assertEqual(len(calls), 3)
        self.assertTrue(all(c[1]['env']['DEVELOPER_DIR'] == '/example/Xcode27/Contents/Developer' for c in calls))

    def test_licence_failure_stops_and_preserves_evidence(self):
        report, calls = self.run_probe([(0, 'Xcode 27.0'), (69, 'You have not agreed to the Xcode license agreements.')])
        self.assertEqual(report['status'], 'blocked')
        self.assertIn('license', report['checks'][-1]['output'])
        self.assertEqual(len(calls), 2)

    def test_old_sdk_cannot_pass_even_with_new_xcode(self):
        report, _ = self.run_probe([(0, 'Xcode 27.0'), (0, '-sdk xros26.5\n-sdk xrsimulator26.5')])
        self.assertEqual(report['status'], 'blocked')
        self.assertIn('SDK', report['reason'])

    def test_simulator_alone_is_not_device_sdk(self):
        report, _ = self.run_probe([(0, 'Xcode 27.0'), (0, '-sdk xrsimulator27.0')])
        self.assertEqual(report['status'], 'blocked')

    def test_missing_command_is_explicit(self):
        report, _ = self.run_probe([FileNotFoundError('xcodebuild absent')])
        self.assertEqual(report['status'], 'blocked')
        self.assertIn('absent', report['checks'][0]['output'])

    def test_timeout_is_not_success(self):
        report, _ = self.run_probe([subprocess.TimeoutExpired(['xcodebuild'], 20)])
        self.assertEqual(report['status'], 'blocked')
        self.assertIn('timed out', report['checks'][0]['output'])

    def test_swift5_rejected(self):
        report, _ = self.run_probe([(0, 'Xcode 27.0'), (0, '-sdk xros27.0\n-sdk xrsimulator27.0'), (0, 'Apple Swift version 5.9')])
        self.assertEqual(report['status'], 'blocked')

    def test_cli_requires_explicit_developer_dir(self):
        result = subprocess.run(['python3', str(SCRIPT)], capture_output=True, text=True)
        self.assertEqual(result.returncode, 2)
        self.assertIn('--developer-dir', result.stderr)

if __name__ == '__main__':
    unittest.main()
