#!/usr/bin/env python3
"""Build synthetic media/Widget source and install only on an emulator, never a car."""
from pathlib import Path
import os,subprocess,zipfile
root=Path(__file__).resolve().parents[1]
serial=os.environ.get('UNI_EMULATOR_SERIAL','emulator-5580')
if not serial.startswith('emulator-') or not serial[9:].isdigit():raise SystemExit('Emulator serial required')
def run(*args):subprocess.run([str(x) for x in args],check=True)
check=subprocess.check_output(['adb','-s',serial,'shell','getprop','ro.kernel.qemu'],text=True).strip()
if check!='1':raise SystemExit('Refusing to install on non-emulator')
t=Path('/tmp/linkco-build');j=t/'root/usr/lib/jvm/java-17-openjdk-amd64/bin';sdk=Path('/data/tools/linkco-android/sdk')
android=sdk/'platforms/android-9/android.jar'
src=root/'test-fixture';out=root/'build/fixture';classes=out/'classes';classes.mkdir(parents=True,exist_ok=True)
run(j/'javac','-source','8','-target','8','-Xlint:-options','-encoding','UTF-8','-bootclasspath',android,'-d',classes,*src.rglob('*.java'))
run(j/'java','-cp',t/'r8.jar','com.android.tools.r8.D8','--min-api','23','--lib',android,'--output',out,*classes.rglob('*.class'))
run(t/'aapt2','compile','--dir',src/'res','-o',out/'res.zip')
run(t/'aapt2','link','-I',android,'--manifest',src/'AndroidManifest.xml','-R',out/'res.zip','-o',out/'unsigned.apk')
with zipfile.ZipFile(out/'unsigned.apk','a',zipfile.ZIP_DEFLATED) as z:z.write(out/'classes.dex','classes.dex')
run(j/'java','-cp',str(t/'root/usr/share/java/apksigner.jar')+':'+str(t/'root/usr/share/java/apksig.jar'),'com.android.apksigner.ApkSignerTool','sign','--ks',sdk.parent/'uni-debug.keystore','--ks-pass','pass:android','--ks-key-alias','uni-debug','--v4-signing-enabled','false','--out',out/'fixture.apk',out/'unsigned.apk')
run('adb','-s',serial,'install','-r',out/'fixture.apk')
print('Synthetic source installed on',serial,'ONLY; package ecarx.xsf.mediacenter is a test fixture, not an OEM APK.')
