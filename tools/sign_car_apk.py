#!/usr/bin/env python3
"""Create a separate IP753 test APK using the owner's existing local signing files.

Does not install, change UID, or include any key in the source repository.
The regular emulator/development APK retains its own certificate.
"""
import argparse
import hashlib
import subprocess
from pathlib import Path

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--input', required=True, type=Path)
parser.add_argument('--out', required=True, type=Path)
parser.add_argument('--toolchain', type=Path, default=Path('/data/tools/linkco-android/ip753-signing'))
args = parser.parse_args()
source = args.input.resolve()
target = args.out.resolve()
if source == target:
    parser.error('Choose a separate output APK; preserve the development artifact')
toolchain = args.toolchain.resolve()
java = Path('/data/tools/linkco-android/java-runtime/usr/lib/jvm/java-17-openjdk-amd64/bin/java')
if not java.is_file(): java = toolchain / 'root/usr/lib/jvm/java-17-openjdk-amd64/bin/java'
jar = Path('/data/tools/linkco-android/sdk/build-tools/36.0.0/lib/apksigner.jar')
key = toolchain / 'platform.pk8'
cert = toolchain / 'platform.x509.pem'
for path in [source, java, jar, key, cert]:
    if not path.is_file():
        parser.error('Missing local input: ' + str(path))
target.parent.mkdir(parents=True, exist_ok=True)
signer = [str(java), '-cp', str(jar), 'com.android.apksigner.ApkSignerTool']
subprocess.run([*signer, 'sign', '--key', str(key), '--cert', str(cert),
                '--v1-signing-enabled', 'true', '--v2-signing-enabled', 'true',
                '--v3-signing-enabled', 'false', '--v4-signing-enabled', 'false',
                '--out', str(target), str(source)], check=True)
verified = subprocess.run([*signer, 'verify', '--print-certs', str(target)],
                          check=True, capture_output=True, text=True).stdout
expected = 'c8a2e9bccf597c2fb6dc66bee293fc13f2fc47ec77bc6b2b0d52c11f51192ab8'
if 'certificate SHA-256 digest: ' + expected not in verified:
    target.unlink()
    raise SystemExit('Certificate does not match the verified IP753 test target')
print('Verified IP753 certificate SHA-256:', expected)
print('APK:', target)
print('APK SHA-256:', hashlib.sha256(target.read_bytes()).hexdigest())
