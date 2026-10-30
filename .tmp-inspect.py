import json
d=json.load(open(r'C:\Users\Gfy\.dsh\attachments\v1\files\b0\b0a0810a5461a4f41e0e6ee13ca90f1bc70dd8ac2bb48d0b88d9aed83375c45e\ys.json',encoding='utf-8'))
print('顶层键:', list(d.keys())[:10])
def walk(o,path='',depth=0):
    if depth>2: return
    if isinstance(o,dict):
        for k,v in list(o.items())[:8]:
            t=type(v).__name__
            n=len(v) if isinstance(v,(list,dict,str)) else ''
            print(' '*depth*2+f'{path}.{k} ({t} {n})')
            walk(v,path+'.'+k,depth+1)
    elif isinstance(o,list) and o:
        print(' '*depth*2+f'{path}[0] ({type(o[0]).__name__})')
        walk(o[0],path+'[0]',depth+1)
walk(d)
