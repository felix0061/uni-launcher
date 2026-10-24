#!/usr/bin/env python3
"""Read-only APK inventory and bytecode extraction for locally supplied launchers."""
import argparse
import hashlib
import json
import re
from pathlib import Path
from loguru import logger
logger.remove()
from androguard.core.apk import APK
from androguard.core.dex import DEX
from androguard.core.axml import AXMLPrinter
from lxml import etree

ANDROID = '{http://schemas.android.com/apk/res/android}'
SKIP = ('Landroid/', 'Landroidx/', 'Lkotlin/', 'Lkotlinx/', 'Ljava/', 'Ljavax/',
        'Lorg/apache/', 'Lorg/bouncycastle/', 'Lcom/google/', 'Lokhttp3/',
        'Lokio/', 'Lio/reactivex/', 'Lcom/fasterxml/')

def analyze(source, destination):
    destination.mkdir(parents=True, exist_ok=True)
    apk = APK(str(source))
    manifest = apk.get_android_manifest_xml()
    (destination / 'AndroidManifest.xml').write_bytes(etree.tostring(manifest, pretty_print=True, encoding='utf-8'))
    components = []
    for kind in ['activity', 'activity-alias', 'service', 'receiver', 'provider']:
        for node in manifest.findall('.//' + kind):
            components.append({'kind': kind,
                **{key.removeprefix(ANDROID): value for key, value in node.attrib.items()},
                'actions': [n.get(ANDROID + 'name') for n in node.findall('.//action')],
                'categories': [n.get(ANDROID + 'name') for n in node.findall('.//category')]})
    certificates = sorted({hashlib.sha256(c).hexdigest() for c in apk.get_certificates_der_v2() + apk.get_certificates_der_v3()})
    inventory = {'file': source.name, 'sha256': hashlib.sha256(source.read_bytes()).hexdigest(),
        'bytes': source.stat().st_size, 'package': apk.get_package(),
        'version_name': apk.get_androidversion_name(), 'version_code': apk.get_androidversion_code(),
        'min_sdk': apk.get_min_sdk_version(), 'target_sdk': apk.get_target_sdk_version(),
        'shared_user_id': manifest.get(ANDROID + 'sharedUserId'),
        'application': {key.removeprefix(ANDROID): value for key, value in manifest.find('application').attrib.items()},
        'certificate_sha256': certificates, 'permissions': sorted(apk.get_permissions()),
        'components': components, 'native_libraries': [f for f in apk.get_files() if f.endswith('.so')],
        'dex': [], 'layouts': []}
    with (destination / 'classes.txt').open('w') as names, (destination / 'strings.txt').open('w') as strings, (destination / 'bytecode.txt').open('w') as code:
        for dexname in apk.get_dex_names():
            dex = DEX(apk.get_file(dexname))
            count = 0
            for string in dex.get_strings():
                strings.write(str(string).replace('\x00', '\\0').replace('\n', '\\n') + '\n')
            for cls in dex.get_classes():
                name = cls.get_name()
                names.write(name + '\n')
                count += 1
                if name.startswith(SKIP):
                    continue
                code.write('\nCLASS ' + name + ' EXTENDS ' + str(cls.get_superclassname()) + '\n')
                for field in cls.get_fields():
                    value = field.get_init_value()
                    code.write('FIELD ' + field.get_name() + ' ' + field.get_descriptor() + (' = ' + str(value.get_value()) if value else '') + '\n')
                for method in cls.get_methods():
                    code.write('\nMETHOD ' + name + '->' + method.get_name() + method.get_descriptor() + '\n')
                    offset = 0
                    for instruction in method.get_instructions():
                        code.write(f'{offset:06x} {instruction.get_name()} {instruction.get_output()}\n')
                        offset += instruction.get_length()
            inventory['dex'].append({'name': dexname, 'classes': count})
            print(source.name, dexname, count, flush=True)
    for name in apk.get_files():
        if name.endswith('.xml') and re.search(r'(^res/(?:layout|xml)[^/]*/|^r/)', name):
            try:
                xml = AXMLPrinter(apk.get_file(name)).get_xml_obj()
                if xml is not None:
                    relative = Path('xml') / name
                    (destination / relative).parent.mkdir(parents=True, exist_ok=True)
                    (destination / relative).write_bytes(etree.tostring(xml, pretty_print=True, encoding='utf-8'))
                    if '/layout' in name or name.startswith('r/'):
                        inventory['layouts'].append(name)
            except Exception:
                pass
    strings = apk.get_android_resources().get_resolved_strings()
    (destination / 'resolved-strings.json').write_text(json.dumps(strings, ensure_ascii=False, indent=2) + '\n')
    (destination / 'inventory.json').write_text(json.dumps(inventory, ensure_ascii=False, indent=2) + '\n')
    print('DONE', destination, flush=True)

if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('apk', type=Path)
    parser.add_argument('output', type=Path)
    arguments = parser.parse_args()
    analyze(arguments.apk.resolve(), arguments.output.resolve())
