#!/usr/bin/env python3
"""Emulator-only cross-app global dock regression; installs nothing.
Temporarily seeds the debug app's overlay/demo flags and restores its exact
preference file afterwards. No real vehicle is accepted; no car commands sent.
Run after installing a normal debug build (not an integration-test entry point).
"""
import argparse,json,re,subprocess,time,xml.etree.ElementTree as ET
from pathlib import Path
p=argparse.ArgumentParser(description=__doc__)
p.add_argument('--serial',default='emulator-5580');p.add_argument('--out',type=Path,default=Path('app/verification/global-dock'))
a=p.parse_args();adb=['adb','-s',a.serial];pkg='xyz.i4o.uni.launcher'
def run(*args,input=None):return subprocess.check_output([*adb,*args],input=input,timeout=40)
def sh(*args):return run('shell',*args).decode().strip()
if not re.fullmatch(r'emulator-\d+',a.serial) or sh('getprop','ro.kernel.qemu')!='1':raise SystemExit('Emulator required')
if sh('getprop','ro.product.cpu.abi')!='x86_64':raise SystemExit('Use the isolated API28 x86_64 emulator')
sh('appops','set',pkg,'SYSTEM_ALERT_WINDOW','allow')
sh('pm','grant',pkg,'android.permission.WRITE_SECURE_SETTINGS')
sh('am','start','-W','-n',pkg+'/.MainActivity')
time.sleep(.5)
pref='shared_prefs/launcher.xml';original=run('shell','run-as',pkg,'cat',pref);root=ET.fromstring(original)
for name,val in [('globalDockEnabled','true'),('demo','true')]:
 n=next((n for n in root if n.get('name')==name),None)
 if n is None:n=ET.SubElement(root,'boolean',{'name':name})
 n.set('value',val)
checks=[];a.out.mkdir(parents=True,exist_ok=True)
def save_pref(data):run('shell','run-as',pkg,'sh','-c',"'cat > shared_prefs/launcher.xml'",input=data)
def check(name,value):
 checks.append({'name':name,'passed':bool(value)})
 if not value:raise AssertionError(name)
def state():
 raw=sh('dumpsys','activity','service',pkg+'/.GlobalDockService')
 line=next((x.split('UNI_GLOBAL_DOCK=',1)[1] for x in raw.splitlines() if 'UNI_GLOBAL_DOCK=' in x),None)
 return json.loads(line) if line else {}
def wait(test):
 for i in range(50):
  s=state()
  if test(s):return s
  time.sleep(.1)
 raise AssertionError('Timed out waiting for dock state: '+str(state()))
def tap(x,y):sh('input','tap',str(x),str(y));time.sleep(.35)
def shot(name):(a.out/(name+'.png')).write_bytes(run('exec-out','screencap','-p'))
try:
 sh('am','force-stop',pkg);save_pref(ET.tostring(root,encoding='utf-8',xml_declaration=True))
 sh('am','start','-W','-n',pkg+'/.MainActivity')
 s=wait(lambda s:s.get('running') and not s.get('visible'))
 check('one inline dock on home, overlay hidden',s['runtimeOwnerCount']==2)
 sh('am','start','-a','android.settings.SETTINGS')
 s=wait(lambda s:s.get('visible') and s.get('rendering'))
 check('global Flutter dock renders over another app',True)
 check('one native data owner while home is stopped',s['runtimeOwnerCount']==1)
 check('only bottom bar receives overlay touches',s['height']==96 and s['width']==1920 and s['x']==0)
 shot('global-dock-external-settings');y=s['y']+48
 before=s['media']['playing'];tap(852,y);s=wait(lambda s:s.get('media',{}).get('playing')!=before)
 check('external play/pause reaches shared media state',True)
 tap(440,y);s=wait(lambda s:s.get('expanded'))
 check('climate panel expands overlay',s['height']>900)
 shot('global-dock-external-climate')
 sh('input','keyevent','4');s=wait(lambda s:not s.get('expanded'))
 check('Back closes panel and restores bounded overlay',s['height']==96)
 tap(440,s['y']+48);wait(lambda s:s.get('expanded'))
 sh('am','start','-W','-n',pkg+'/.MainActivity')
 wait(lambda s:not s.get('visible') and not s.get('expanded'))
 sh('am','start','-a','android.settings.SETTINGS')
 s=wait(lambda s:s.get('visible') and not s.get('expanded'))
 check('external HOME discards the old panel before another app',s['height']==96)
 tap(84,s['y']+48);s=wait(lambda s:not s.get('visible'))
 check('Home returns to launcher without double dock',s['runtimeOwnerCount']==2)
 sh('am','start','-a','android.settings.SETTINGS');s=wait(lambda s:s.get('visible') and s.get('rendering'))
 sh('input','swipe','84',str(s['y']+48),'84',str(s['y']+48),'900')
 s=wait(lambda s:not s.get('visible'))
 raw=sh('dumpsys','activity',pkg+'/.MainActivity','--uni-state')
 j=json.loads(next(x.split('UNI_STATE=',1)[1] for x in raw.splitlines() if 'UNI_STATE=' in x))
 check('holding global Home opens desktop settings',j.get('flutterViewport',{}).get('settings') is True)
 pid=sh('pidof',pkg);logs=sh('logcat','-d','--pid='+pid)
 check('no fatal or Dart rendering failure',not re.search(r'FATAL EXCEPTION|Unhandled Exception|Could not resolve main entrypoint|A RenderFlex overflowed',logs))
finally:
 sh('am','force-stop',pkg);save_pref(original)
 (a.out/'external-report.json').write_text(json.dumps({'checks':checks,'passed':sum(c['passed'] for c in checks),'scope':'API28 emulator only; shared demo commands, no vehicle','preferencesRestored':True},ensure_ascii=False,indent=2)+'\n')
print('PASS',len(checks),'cross-app dock checks; original preferences restored')
