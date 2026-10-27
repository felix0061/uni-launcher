#!/usr/bin/env python3
"""Read-only traffic-signal export evidence from a locally supplied APK.

Requires androguard. Does not load or execute APK code. Large bytecode extracts
belong in ignored analysis/raw; retain only reviewed evidence summaries in Git.
Use --references to follow an obfuscated notifier/interface after the first pass.
"""
import argparse
import hashlib
import json
import re
import zipfile
from contextlib import ExitStack
from pathlib import Path

from loguru import logger

logger.remove()
from androguard.core.apk import APK
from androguard.core.dex import DEX

ANDROID = '{http://schemas.android.com/apk/res/android}'
SIGNAL = re.compile(
    r'traffic.?light|traffic.?lamp|signal.?light|red.?light|traffic.?signal|红绿灯|灯态',
    re.IGNORECASE,
)


def attributes(node):
    return {key.removeprefix(ANDROID): value for key, value in node.attrib.items()}


def analyze(source, output, references=None):
    output.mkdir(parents=True, exist_ok=True)
    apk = APK(str(source))
    manifest = apk.get_android_manifest_xml()
    components = []
    for kind in ('service', 'receiver', 'provider'):
        for node in manifest.iter(kind):
            components.append({
                'kind': kind,
                **attributes(node),
                'actions': [item.get(ANDROID + 'name') for item in node.iter('action')],
            })
    report = {
        'file': source.name,
        'package': apk.get_package(),
        'version': apk.get_androidversion_name(),
        'versionCode': apk.get_androidversion_code(),
        'sha256': hashlib.sha256(source.read_bytes()).hexdigest(),
        'permissions': [attributes(node) for node in manifest.findall('permission')],
        'components': components,
        'dex': [],
        'nativeSignalStrings': [],
    }
    with ExitStack() as stack:
        archive = stack.enter_context(zipfile.ZipFile(source))
        files = {
            name: stack.enter_context((output / (name + '.txt')).open(
                'w', encoding='utf-8', errors='backslashreplace'))
            for name in ('signal-bytecode', 'broadcast-bytecode', 'reference-bytecode', 'strings')
        }
        for name in archive.namelist():
            if re.fullmatch(r'classes\d*\.dex', name):
                dex = DEX(archive.read(name))
                selected, broadcasts, referenced = [], [], []
                for value in dex.get_strings():
                    files['strings'].write(str(value).replace('\n', '\\n').replace('\0', '\\0') + '\n')
                for cls in dex.get_classes():
                    class_info = cls.get_name() + ' ' + str(cls.get_interfaces())
                    for method in cls.get_methods():
                        header = cls.get_name() + '->' + method.get_name() + method.get_descriptor()
                        rows, offset = [], 0
                        for instruction in method.get_instructions():
                            rows.append(f'{offset:06x} {instruction.get_name()} {instruction.get_output()}')
                            offset += instruction.get_length()
                        body = '\n'.join(rows)
                        text = header + '\n' + body
                        record = '\nMETHOD ' + text + '\n'
                        if SIGNAL.search(text):
                            files['signal-bytecode'].write(record)
                            selected.append(header)
                        if any(word in body for word in (
                            '->sendBroadcast', '->sendStickyBroadcast', '->sendOrderedBroadcast',
                        )):
                            files['broadcast-bytecode'].write(record)
                            broadcasts.append(header)
                        if references and references.search(class_info + '\n' + text):
                            files['reference-bytecode'].write(record)
                            referenced.append(header)
                report['dex'].append({
                    'file': name, 'signalMethods': selected,
                    'broadcastMethods': broadcasts, 'referenceMethods': referenced,
                })
                print(name, len(selected), 'signal methods', len(broadcasts), 'broadcast senders', flush=True)
            elif name.endswith(('.so', '.lua', '.js', '.json')):
                hits = [match[0].decode() for match in re.finditer(
                    rb'[\x20-\x7e]{6,}', archive.read(name)) if SIGNAL.search(match[0].decode())]
                if hits:
                    report['nativeSignalStrings'].append({'file': name, 'strings': hits})
    (output / 'inventory.json').write_text(json.dumps(report, ensure_ascii=True, indent=2) + '\n')
    print(report['package'], report['version'], flush=True)


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('apk', type=Path)
    parser.add_argument('--out', required=True, type=Path)
    parser.add_argument('--references', type=re.compile, help='Regex for exact class/method references')
    arguments = parser.parse_args()
    analyze(arguments.apk, arguments.out, arguments.references)
