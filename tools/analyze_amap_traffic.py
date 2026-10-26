#!/usr/bin/env python3
"""Read-only traffic-light evidence from the owner's two local AMap APKs."""
import argparse
import hashlib
import json
from pathlib import Path
import re
import zipfile
from loguru import logger
logger.remove()
from androguard.core.dex import DEX
from androguard.core.apk import APK

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('directory', type=Path)
parser.add_argument('--out', type=Path, default=Path('analysis/raw/amap'))
args = parser.parse_args()
pattern = re.compile(r'traffic.?light|red.?light|light.?count|lightsData|countDown|count_down|signal.?light|60073|0xeaa9|红绿灯', re.I)
inventories = {}
for source in sorted(args.directory.glob('*.apk')):
    label = 'official' if source.name.startswith('Auto') else 'modified'
    out = args.out / label
    out.mkdir(parents=True, exist_ok=True)
    apk = APK(str(source))
    (out / 'inventory.json').write_text(json.dumps({
        'file': source.name, 'package': apk.get_package(),
        'version': apk.get_androidversion_name(), 'versionCode': apk.get_androidversion_code(),
        'sha256': hashlib.sha256(source.read_bytes()).hexdigest(),
    }, ensure_ascii=False, indent=2) + '\n')
    with zipfile.ZipFile(source) as archive:
        inventories[label] = {entry.filename: (entry.CRC, entry.file_size) for entry in archive.infolist()}
        with (out / 'dex-strings.txt').open('w') as strings, (out / 'traffic-bytecode.txt').open('w') as code, (out / 'dispatch-bytecode.txt').open('w') as dispatch:
            for name in archive.namelist():
                if not re.fullmatch(r'classes\d*\.dex', name):
                    continue
                dex = DEX(archive.read(name))
                for value in dex.get_strings():
                    strings.write(str(value).replace('\n', '\\n') + '\n')
                count = 0
                for cls in dex.get_classes():
                    whole_class = bool(pattern.search(cls.get_name()))
                    for method in cls.get_methods():
                        header = cls.get_name() + '->' + method.get_name() + method.get_descriptor()
                        instructions = []
                        offset = 0
                        for instruction in method.get_instructions():
                            instructions.append(f'{offset:06x} {instruction.get_name()} {instruction.get_output()}')
                            offset += instruction.get_length()
                        body = '\n'.join(instructions)
                        if (cls.get_name() == 'Lec;' or 'Lwh0;' in body
                            or 'AUTONAVI_STANDARD_BROADCAST_SEND' in body
                            or 'CruiseTrafficLightBroadcaster;->init' in body):
                            dispatch.write('\nMETHOD ' + header + '\n' + body + '\n')
                        if whole_class or pattern.search(header + '\n' + body):
                            code.write('\nMETHOD ' + header + '\n' + body + '\n')
                            count += 1
                print(label, name, 'selected methods', count, flush=True)
        native = []
        for name in archive.namelist():
            if not name.endswith(('.so', '.lua', '.js', '.json')):
                continue
            raw = archive.read(name)
            hits = []
            for match in re.finditer(rb'[\x20-\x7e]{5,}', raw):
                value = match[0].decode()
                if pattern.search(value):
                    hits.append(value)
            if hits:
                native.append({'file': name, 'sha256': hashlib.sha256(raw).hexdigest(), 'strings': hits})
        (out / 'native-traffic-strings.json').write_text(json.dumps(native, ensure_ascii=False, indent=2) + '\n')
        print(label, 'native files with matches', len(native), flush=True)
if len(inventories) == 2:
    a, b = inventories['official'], inventories['modified']
    changed = {'added': sorted(b.keys() - a.keys()), 'removed': sorted(a.keys() - b.keys()),
               'changed': sorted(k for k in a.keys() & b.keys() if a[k] != b[k]),
               'identicalEntries': sum(a[k] == b[k] for k in a.keys() & b.keys())}
    (args.out / 'zip-difference.json').write_text(json.dumps(changed, ensure_ascii=False, indent=2) + '\n')
