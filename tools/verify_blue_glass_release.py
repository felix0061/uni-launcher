#!/usr/bin/env python3
"""Release/AOT smoke, pinned to the isolated API28 1920x1080 emulator.
Uses this app's known design coordinates and native diagnostics; deliberately
avoids UIAutomator waitForIdle, which is unsuitable for a live media desktop.
No vehicle, run-as, private preferences or media permissions are touched.
"""
import argparse
import io
import re
import json
from pathlib import Path
import subprocess
import time
from PIL import Image

ADB = ['/data/tools/linkco-android/sdk/platform-tools/adb', '-s', 'emulator-5580']
PKG = 'xyz.i4o.uni.launcher'
ROOT = Path(__file__).resolve().parents[1]
parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--out', type=Path, default=ROOT / 'app/verification/blue-glass')
args = parser.parse_args()
OUT = args.out
OUT.mkdir(parents=True, exist_ok=True)
VERSION = re.search(r'^version: ([^+\s]+)', (ROOT / 'app/pubspec.yaml').read_text(), re.M)[1]
checks = []

def run(*args):
    return subprocess.check_output([*ADB, *args], timeout=30)

def sh(*args):
    return run('shell', *args).decode().strip()

def check(name, valid):
    checks.append({'name': name, 'passed': bool(valid)})
    if not valid:
        raise AssertionError(name)

def state():
    raw = sh('dumpsys', 'activity', PKG + '/.MainActivity', '--uni-state')
    return next((json.loads(line.split('UNI_STATE=', 1)[1]) for line in raw.splitlines() if 'UNI_STATE=' in line), {})

def launch(settings=False):
    args = ['am', 'start', '-W', '-n', PKG + '/.MainActivity']
    if settings:
        args += ['--ez', 'uniSettings', 'true']
    sh(*args)
    time.sleep(.8)
    if PKG not in sh('dumpsys', 'window', 'windows').split('mCurrentFocus=')[-1].split('\n')[0]:
        raise AssertionError('Launcher must own the foreground before input')

def tap(x, y):
    sh('input', 'tap', str(x), str(y))
    time.sleep(.4)

def shot(name):
    data = run('exec-out', 'screencap', '-p')
    (OUT / name).write_bytes(data)
    return Image.open(io.BytesIO(data)).convert('RGB')

check('isolated API28 x86_64 1920x1080 emulator', sh('getprop', 'ro.kernel.qemu') == '1'
    and sh('getprop', 'ro.product.cpu.abi') == 'x86_64'
    and sh('getprop', 'ro.build.version.sdk') == '28'
    and sh('wm', 'size') == 'Physical size: 1920x1080')
launch()
check('installed release is ' + VERSION, state().get('version') == VERSION + '-flutter')
check('idle spectrum does not capture audio', state().get('audioSpectrum', {}).get('running') is False)
if state().get('globalDock', {}).get('running'):
    raise AssertionError('This fixture requires the inline dock')
launch(settings=True)
# App-owned 1920px design: first tab, first theme, dark mode, ice-blue palette.
# The coordinates are inside each control in both compact and full-height settings.
tap(110, 210)
tap(340, 367)
tap(1070, 539)
tap(398, 735)
shot('blue-glass-release-theme-picker.png')
launch()
image = shot('blue-glass-release-home.png')
check('first theme choice paints dark blue glass', image.getpixel((960, 50)) == (7, 17, 31))
sh('am', 'force-stop', PKG)
launch()
image = shot('blue-glass-release-restarted.png')
check('theme survives process death', image.getpixel((960, 50)) == (7, 17, 31))
launch(settings=True)
tap(450, 210)
shot('blue-glass-release-settings.png')
check('system settings renders after restart without losing host', state().get('flutterViewport', {}).get('settings') is True)
launch()
report = {'version': VERSION, 'scope': 'API28 release/AOT emulator; first theme choice, painted background and process restart persistence. Actual screenshots also retained; detailed semantics verified by Flutter integration tests.', 'checks': checks}
(OUT / 'release-smoke-report.json').write_text(json.dumps(report, ensure_ascii=False, indent=2) + '\n')
print(f'{len(checks)} release checks passed')
