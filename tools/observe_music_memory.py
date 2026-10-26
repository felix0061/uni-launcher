#!/usr/bin/env python3
"""Read-only music/process/PSS sampling; never changes playback or the UI."""
import argparse
import json
from pathlib import Path
import re
import subprocess
import time


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--serial', required=True)
    parser.add_argument('--player', default='com.netease.cloudmusic.iot')
    parser.add_argument('--duration', type=int, default=180)
    parser.add_argument('--interval', type=int, default=30)
    parser.add_argument('--out', type=Path, required=True)
    args = parser.parse_args()
    if args.interval < 1 or args.duration < args.interval:
        parser.error('duration must be >= interval >= 1')
    args.out.mkdir(parents=True, exist_ok=True)

    def shell(*command):
        return subprocess.check_output(
            ['adb', '-s', args.serial, 'shell', *command],
            timeout=20, text=True, errors='replace')

    rows, start = [], time.monotonic()
    for sample in range(args.duration // args.interval + 1):
        if sample:
            time.sleep(max(0, sample * args.interval - (time.monotonic() - start)))
        row = {'elapsedSec': round(time.monotonic() - start)}
        try:
            raw = shell('dumpsys', 'activity', 'service',
                        'xyz.i4o.uni.launcher/.GlobalDockService')
            payload = next(line.split('UNI_GLOBAL_DOCK=', 1)[1]
                           for line in raw.splitlines() if 'UNI_GLOBAL_DOCK=' in line)
            dock = json.loads(payload)
            for key in ['media', 'liveFlutterEngines', 'panelEngineAlive']:
                row[key] = dock.get(key)
            row['playerPid'] = shell('pidof', args.player).strip()
            for key, package in [('launcher', 'xyz.i4o.uni.launcher'),
                                 ('player', args.player)]:
                memory = shell('dumpsys', 'meminfo', package)
                (args.out / f'{sample}-{key}-mem.txt').write_text(memory)
                total = re.search(r'TOTAL:\s+(\d+)', memory)
                row[key + 'PssKiB'] = int(total[1]) if total else None
        except (subprocess.SubprocessError, ValueError, StopIteration) as error:
            row['error'] = str(error)
        rows.append(row)
        (args.out / 'music-memory-observation.json').write_text(
            json.dumps(rows, ensure_ascii=False, indent=2) + '\n')
        print(json.dumps(row, ensure_ascii=False), flush=True)


if __name__ == '__main__':
    main()
