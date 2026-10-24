#!/usr/bin/env python3
"""Run Flutter with local VM-service connections and the existing Java proxy settings."""
import os,re,shlex,subprocess,sys,urllib.parse
from pathlib import Path
env=os.environ.copy()
proxy=urllib.parse.urlsplit(env.get('https_proxy') or env.get('HTTPS_PROXY') or '')
if proxy.hostname and not proxy.username and re.fullmatch(r'[A-Za-z0-9_.:-]+',proxy.hostname):
    options={f'{kind}.proxyHost':proxy.hostname for kind in ['http','https']}
    options.update({f'{kind}.proxyPort':str(proxy.port or 80) for kind in ['http','https']})
    env['GRADLE_OPTS']=env.get('GRADLE_OPTS','')+' '+' '.join(shlex.quote('-D'+key+'='+value) for key,value in options.items())
env['NO_PROXY']=env['no_proxy']='localhost,127.0.0.1,::1'
if any(arg in ['test','drive'] for arg in sys.argv[1:]):
    for key in ['http_proxy','https_proxy','HTTP_PROXY','HTTPS_PROXY','ALL_PROXY','all_proxy']:env.pop(key,None)
flutter=Path(env.get('FLUTTER_SDK','/data/tools/flutter'))/'bin/flutter'
raise SystemExit(subprocess.run([str(flutter),*sys.argv[1:]],env=env,cwd=Path(__file__).resolve().parents[1]).returncode)
