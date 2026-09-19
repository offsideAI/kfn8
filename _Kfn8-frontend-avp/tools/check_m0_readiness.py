#!/usr/bin/env python3
"""Read-only toolchain check. Never accepts licences or claims a device gate pass."""
import argparse
import json
import os
import re
import subprocess


def probe(developer_dir, runner=subprocess.run):
    report = {
        'developer_dir': developer_dir,
        'status': 'blocked',
        'm0_passed': False,
        'checks': [],
        'reason': '',
    }
    environment = dict(os.environ, DEVELOPER_DIR=developer_dir)
    commands = [
        (['xcodebuild', '-version'], r'Xcode\s+(\d+)', 27, 'Xcode 27 or later required'),
        (['xcodebuild', '-showsdks'], None, None, 'visionOS device and simulator SDK 27 required'),
        (['xcrun', 'swift', '--version'], r'Swift version\s+(\d+)', 6, 'Swift 6 or later required'),
    ]
    for argv, pattern, minimum, failure in commands:
        try:
            result = runner(argv, env=environment, capture_output=True, text=True, timeout=20, check=False)
            code = result.returncode
            output = result.stdout + result.stderr
        except subprocess.TimeoutExpired:
            code, output = 124, 'Command timed out after 20 seconds'
        except OSError as error:
            code, output = 127, str(error)
        report['checks'].append({'command': argv, 'exit_code': code, 'output': output.strip()})
        if code:
            report['reason'] = 'Command failed; inspect recorded output. No setup or licence changes made.'
            return report
        if pattern:
            match = re.search(pattern, output)
            valid = match is not None and int(match.group(1)) >= minimum
        else:
            valid = all(re.search(r'-sdk\s+' + sdk + r'27(?:\.\d+)*(?=\s|$)', output)
                        for sdk in ('xros', 'xrsimulator'))
        if not valid:
            report['reason'] = failure
            return report
    report['status'] = 'toolchain_ready_device_unverified'
    report['reason'] = ('Toolchain commands succeeded. Signing, M2 deployment and measured lighting, '
                        'occlusion and manipulation gates still require device evidence.')
    return report


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--developer-dir', required=True, help='Explicit Xcode Contents/Developer path')
    args = parser.parse_args()
    report = probe(args.developer_dir)
    print(json.dumps(report, indent=2))
    return 0 if report['status'] == 'toolchain_ready_device_unverified' else 1


if __name__ == '__main__':
    raise SystemExit(main())
