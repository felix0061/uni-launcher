#!/usr/bin/env python3
"""Synthetic traffic broadcasts against the real Runtime, strictly emulator-only.

Requires the normal debuggable launcher APK (not the gallery entrypoint). Saves
and restores emulator preferences. Does not install either third-party AMap APK.
"""
import argparse
import json
from pathlib import Path
import re
import shlex
import subprocess
import time
import xml.etree.ElementTree as ET

root = Path(__file__).resolve().parents[1]
parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--serial', default='emulator-5580')
parser.add_argument('--out', type=Path, default=root / 'app/verification/traffic-lights')
args = parser.parse_args()
if not re.fullmatch(r'emulator-\d+', args.serial):
    parser.error('Emulator serial required')
adb = ['/data/tools/linkco-android/sdk/platform-tools/adb', '-s', args.serial]
package = 'xyz.i4o.uni.launcher'


def run(*command, data=None, check=True):
    return subprocess.run(adb + list(command), input=data, stdout=subprocess.PIPE,
                          stderr=subprocess.PIPE, timeout=30, check=check)


def shell(*command):
    return run('shell', shlex.join(command)).stdout.decode().strip()


if shell('getprop', 'ro.kernel.qemu') != '1':
    raise SystemExit('Refusing to change a physical device')
args.out.mkdir(parents=True, exist_ok=True)
shell('am', 'force-stop', package)
original = run('exec-out', 'run-as', package, 'cat', 'shared_prefs/launcher.xml', check=False)
if b'not debuggable' in original.stderr + original.stdout:
    raise SystemExit('Install the normal debug APK first')
try:
    original_data = original.stdout if ET.fromstring(original.stdout).tag == 'map' else None
except ET.ParseError:
    original_data = None
checks, samples = [], {}


def check(name, condition):
    if not condition:
        raise AssertionError(name)
    checks.append(name)


def write_prefs(raw):
    shell('run-as', package, 'mkdir', '-p', 'shared_prefs')
    run('shell', shlex.join(['run-as', package, 'sh', '-c', 'cat > shared_prefs/launcher.xml']), data=raw)


def start(selected):
    shell('am', 'force-stop', package)
    tree = ET.fromstring(original_data if original_data is not None else b'<map/>')
    values = {'navigationPackage': ('string', selected), 'demo': ('boolean', 'false'),
              'embedNavigation': ('boolean', 'false'), 'globalDockEnabled': ('boolean', 'false'),
              'appNames': ('string', json.dumps({selected: '信号测试地图'}, ensure_ascii=False)),
              'savedDesign': ('string', json.dumps({'version': 6, 'pageCount': 1,
                  'preferences': {'mode': 'dark', 'palette': 'mint', 'custom': '#71e4ce', 'radius': 24},
                  'cards': [{'id': 'signal-test', 'type': 'trafficLight', 'title': '红绿灯', 'x': 0, 'y': 0, 'w': 4, 'h': 3, 'page': 0}]}, ensure_ascii=False))}
    for child in list(tree):
        if child.get('name') in values:
            tree.remove(child)
    for name, (kind, value) in values.items():
        node = ET.SubElement(tree, kind, {'name': name})
        if kind == 'string':
            node.text = value
        else:
            node.set('value', value)
    write_prefs(ET.tostring(tree, encoding='utf-8', xml_declaration=True))
    shell('am', 'start', '-W', '-n', package + '/.MainActivity')
    return wait(lambda value: value.get('package') == selected)


def state():
    dump = shell('dumpsys', 'activity', package + '/.MainActivity', '--uni-state')
    for line in dump.splitlines():
        if 'UNI_STATE=' in line:
            return json.loads(line.split('UNI_STATE=', 1)[1])['trafficLights']
    return {}


def wait(predicate, timeout=12):
    deadline = time.monotonic() + timeout
    while time.monotonic() < deadline:
        value = state()
        if predicate(value):
            return value
        time.sleep(.1)
    raise AssertionError('Traffic state did not settle: ' + json.dumps(value))


def standard(**values):
    command = ['am', 'broadcast', '--receiver-foreground', '-a', 'AUTONAVI_STANDARD_BROADCAST_SEND']
    for name, value in {'KEY_TYPE': 60073, 'dir': 8, 'trafficLightStatus': 2, 'redLightCountDownSeconds': 60, **values}.items():
        command += ['--ei' if isinstance(value, int) else '--es', name, str(value)]
    shell(*command)


def cruise(lights):
    shell('am', 'broadcast', '--receiver-foreground', '-a', 'NAVITOOL_CRUISE_TRAFFIC_LIGHTS',
          '--es', 'data', json.dumps({'ts': int(time.time() * 1000), 'lights': lights}, separators=(',', ':')))


def shot(name):
    (args.out / (name + '.png')).write_bytes(run('exec-out', 'screencap', '-p').stdout)


try:
    start('com.autonavi.amapauto')
    standard()
    value = wait(lambda s: s.get('available') is True)
    samples['standard'] = value
    check('official broadcast received by Runtime', value['lights'][0]['countdownSeconds'] == 60)
    check('raw enums retained without inventing colors', value['lights'][0]['rawDirection'] == 8 and value['lights'][0]['lamp'] == 'unknown')
    shot('native-standard-unknown')
    seq = value['sequence']
    standard(KEY_TYPE=10001)
    check('route light counts do not replace countdowns', state()['sequence'] == seq)
    standard(dir='invalid')
    check('malformed direction rejected', state()['sequence'] == seq)
    expired = wait(lambda s: s.get('reason') == 'expired')
    check('timeout clears every direction', not expired['available'] and not expired['lights'])
    shot('native-expired')
    start('com.autonavi.amapautp.yh')
    cruise([{'direction': 1, 'status': 2, 'countdown': 60}, {'direction': 8, 'status': 4, 'countdown': 24}])
    value = wait(lambda s: len(s.get('lights', [])) == 2)
    samples['cruise'] = value
    check('modified cruise batch received atomically', [s['countdownSeconds'] for s in value['lights']] == [60, 24])
    seq = value['sequence']
    standard()
    check('fresh multi-direction batch survives concurrent standard sample', state()['sequence'] == seq)
    cruise([{'direction': 1, 'status': 2, 'countdown': 40}, {}])
    check('malformed multi-direction batch never partially replaces data', state()['sequence'] == seq)
    cruise([])
    empty = wait(lambda s: not s.get('lights'))
    check('explicit empty batch clears immediately', not empty['available'])
    start('com.example.other.navigation')
    standard()
    cruise([{'direction': 1, 'status': 2, 'countdown': 60}])
    check('other navigation association ignores AMap data', not state()['available'])
    (args.out / 'native-report.json').write_text(json.dumps({'device': args.serial,
        'source': 'synthetic broadcasts only, not live AMap road data',
        'checks': checks, 'samples': samples}, ensure_ascii=False, indent=2) + '\n')
    print(f'{len(checks)} Android Runtime traffic-light checks passed')
finally:
    shell('am', 'force-stop', package)
    if original_data is not None:
        write_prefs(original_data)
    else:
        shell('run-as', package, 'rm', '-f', 'shared_prefs/launcher.xml')
