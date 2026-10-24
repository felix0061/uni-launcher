#!/usr/bin/env python3
"""Read-only readiness evidence. Does not connect, install, launch or control a vehicle."""
import argparse,json,subprocess
from datetime import datetime,timezone
from pathlib import Path

p=argparse.ArgumentParser(description=__doc__)
p.add_argument('--serial',required=True)
p.add_argument('--out',type=Path,required=True)
a=p.parse_args()
if a.out.exists() and any(a.out.iterdir()):raise SystemExit('Choose an empty output directory')
a.out.mkdir(parents=True,exist_ok=True)
commands={
 'product':['getprop','ro.product.name'], 'android':['getprop','ro.build.version.release'],
 'size':['wm','size'], 'density':['wm','density'],
 'windows':['dumpsys','window','windows'], 'services':['service','list'],
 'widgets':['dumpsys','appwidget'], 'media':['dumpsys','media_session'],
}
for package in ['xyz.i4o.uni.launcher','ecarx.launcher3','com.autonavi.amapauto','com.autonavi.amapautolite','com.autonavi.minimap','ecarx.xsf.mediacenter','com.netease.cloudmusic','com.netease.cloudmusic.iot','com.tencent.qqmusic','com.tencent.qqmusiccar','com.ecarx.xcvehicle','com.ecarx.hvac']:
 commands['package-'+package]=['dumpsys','package',package]
results={}
for name,command in commands.items():
 try:
  r=subprocess.run(['adb','-s',a.serial,'shell',*command],capture_output=True,text=True,timeout=15)
  text=r.stdout
  if name=='windows':text='\n'.join(l for l in text.splitlines() if any(k in l for k in ['mCurrentFocus','mFocusedApp','mDisplayFrame','mStable','mContentFrame']))
  if name=='media':text='\n'.join(l for l in text.splitlines() if any(k in l for k in ['package=','active=','state=PlaybackState','authorized','sessions listeners']))
  if name=='widgets':text='\n'.join(l for l in text.splitlines() if any(k in l for k in ['provider=','ProviderId','host=','HostId','packageName=']))
  (a.out/(name+'.txt')).write_text(text+'\n')
  results[name]={'exitCode':r.returncode,'stderr':r.stderr[:300]}
 except subprocess.TimeoutExpired:results[name]={'error':'timeout'}
(a.out/'collection.json').write_text(json.dumps({'collectedAtUtc':datetime.now(timezone.utc).isoformat(),'readOnly':True,'results':results},ensure_ascii=False,indent=2)+'\n')
print('Read-only evidence written to',a.out)
