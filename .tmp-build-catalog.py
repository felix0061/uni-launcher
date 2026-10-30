import json, io, sys
sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8', errors='replace')
d=json.load(open(r'C:\Users\Gfy\.dsh\attachments\v1\files\b0\b0a0810a5461a4f41e0e6ee13ca90f1bc70dd8ac2bb48d0b88d9aed83375c45e\ys.json',encoding='utf-8'))
sp=d['Result']['Speakers']
out=[]
for x in sp:
    cats=[]
    for c in (x.get('Categories') or []):
        for cc in (c.get('Categories') or []):
            if cc not in cats: cats.append(cc)
    out.append({
        'v': x.get('VoiceType',''),
        'n': (x.get('Name') or '').strip(),
        'g': x.get('Gender',''),
        'a': x.get('Age',''),
        'e': x.get('Emoji') or '',
        'd': (x.get('Description') or '').strip(),
        't': x.get('TrialURL') or '',
        'h': x.get('Heat') or 0,
        'c': cats,
        'r': x.get('ResourceID') or 'seed-tts-2.0',
    })
# 热度降序，稳定的默认顺序
out.sort(key=lambda o: -o['h'])
path='app/android/voice/src/main/assets/volcano_voices.json'
import os
os.makedirs(os.path.dirname(path), exist_ok=True)
with open(path,'w',encoding='utf-8') as f:
    json.dump(out,f,ensure_ascii=False,separators=(',',':'))
print('写入', path, '条数', len(out), '大小', os.path.getsize(path)//1024, 'KB')
print('前5:', [(o['n'],o['g'],o['h'],o['e']) for o in out[:5]])
print('无试听:', sum(1 for o in out if not o['t']))
print('无名字:', sum(1 for o in out if not o['n']))
