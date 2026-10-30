"""Summarize bounded SF presentation intervals, scheduler runtime and atrace slices.

CPU percentages use one core = 100%. Slice durations are inclusive wall time,
not CPU time. This is not a Dart stack profiler or a physical input latency test.
"""
import argparse
import collections
import json
import pathlib
import re


LINE=re.compile(r'^\s*(.+?)-(\d+)\s+\(\s*(\d+|-----)\)\s+\[(\d+)\]\s+\S+\s+(\d+\.\d+):\s+(\w+):\s+(.*)$')
SWITCH=re.compile(r'prev_comm=(.*?) prev_pid=(\d+) prev_prio=\d+ prev_state=(.*?) ==> next_comm=(.*?) next_pid=(\d+)')


def stats(values):
    if not values:return {'count':0}
    a=sorted(values)
    def q(f):return round(a[round((len(a)-1)*f)],3)
    return {'count':len(a),'mean':round(sum(a)/len(a),3),'p50':q(.5),'p90':q(.9),'p99':q(.99),'max':round(a[-1],3)}


def analyze(root):
    meta=json.loads((root/'metadata.json').read_text())
    action=(root/'action.txt').read_text()
    times=re.findall(r'uptimeMs=(\d+)',action)
    if times:start,end=[int(x)/1000 for x in times]
    else:
        times=[float(x.split()[0]) for x in action.splitlines() if re.match(r'^\d+\.\d+ ',x)]
        start,end=times[0],times[-1]
    # For a tap report a fixed 500 ms response window, explicitly distinct from
    # the host-side adb command duration. Inspect trace for exact dispatch time.
    if meta.get('tap'):end=start+.5
    names={};owners={};process_names={}
    for l in (root/'threads.txt').read_text().splitlines():
        v=l.split()
        if len(v)>=10 and v[1].isdigit() and v[2].isdigit():
            pid,tid=int(v[1]),int(v[2]);owners[tid]=pid;names[tid]=v[-1]
            if pid==tid:process_names[pid]=v[-1]
    cpu=collections.defaultdict(float);on_cpu={};stacks=collections.defaultdict(list)
    slices=collections.defaultdict(list);slice_events=[];preempt=collections.defaultdict(list)
    ready={};first=last=None;unparsed=0
    with (root/'interaction.ftrace').open(errors='replace') as f:
        for l in f:
            m=LINE.match(l)
            if not m:
                if not l.startswith('#') and l.strip():unparsed+=1
                continue
            name,tid,pid,core,at,event,detail=m.groups();tid=int(tid);core=int(core);at=float(at)
            first=at if first is None else first;last=at
            names.setdefault(tid,name.strip())
            if pid!='-----':owners.setdefault(tid,int(pid))
            if event=='sched_switch':
                sw=SWITCH.match(detail)
                if not sw:continue
                pn,prev,state,nn,nxt=sw.groups();prev=int(prev);nxt=int(nxt)
                if core in on_cpu:
                    running,began=on_cpu[core]
                    if running==prev:cpu[prev]+=max(0,min(at,end)-max(began,start))
                if state.startswith('R'):ready[prev]=at
                if nxt in ready:
                    began=ready.pop(nxt)
                    if start<=began<at<=end:preempt[nxt].append((at-began)*1000)
                on_cpu[core]=(nxt,at);names.setdefault(prev,pn);names.setdefault(nxt,nn)
            elif event=='tracing_mark_write':
                if detail.startswith('B|'):
                    bits=detail.split('|',2)
                    if len(bits)==3:stacks[tid].append((at,bits[2]))
                elif detail.startswith('E') and stacks[tid]:
                    began,label=stacks[tid].pop()
                    if start<=began<at<=end:
                        ms=(at-began)*1000;slices[(tid,label)].append(ms)
                        if ms>=16.67:slice_events.append({'tid':tid,'name':label,'start':began,'durationMs':round(ms,3)})
    for tid,began in on_cpu.values():cpu[tid]+=max(0,min(last,end)-max(began,start))
    processes=collections.defaultdict(float)
    for tid,seconds in cpu.items():processes[owners.get(tid,tid)]+=seconds
    threads=[{'tid':tid,'pid':owners.get(tid),'name':names.get(tid),'cpuMs':round(seconds*1000,2),
              'cpuPercent':round(seconds/(end-start)*100,2),'preemptionWaitMs':stats(preempt[tid])}
             for tid,seconds in sorted(cpu.items(),key=lambda kv:-kv[1])[:30] if tid!=0]
    process_stats=[{'pid':pid,'name':process_names.get(pid,names.get(pid)),
                    'cpuPercent':round(seconds/(end-start)*100,2)}
                   for pid,seconds in sorted(processes.items(),key=lambda kv:-kv[1])[:25] if pid!=0]
    latency=json.loads((root/'latency.json').read_text());frames={}
    for layer,raw in latency.items():
        present=[]
        for l in raw.splitlines():
            v=l.split()
            if len(v)==3 and all(x.isdigit() for x in v):
                t=int(v[1])/1e9
                if start<=t<=end:present.append(t)
        present=sorted(set(present));deltas=[(b-a)*1000 for a,b in zip(present,present[1:])]
        frames[layer]={'presentedInWindow':len(present),'presentRate':round(len(present)/(end-start),2),
                       'intervalMs':stats(deltas),'firstPresent':present[0] if present else None,
                       'lastPresent':present[-1] if present else None,
                       'over50ms':sum(x>50.5 for x in deltas),'over100ms':sum(x>100.5 for x in deltas)}
    target_pids={pid for pid,name in process_names.items() if 'launcher' in name or 'amapaut' in name}
    durations=[{'tid':tid,'thread':names.get(tid),'pid':owners.get(tid),'slice':name,
                'totalMs':round(sum(v),3),'durationMs':stats(v)} for (tid,name),v in slices.items()
               if owners.get(tid) in target_pids]
    durations.sort(key=lambda x:-x['totalMs'])
    def state(file):
        try:
            j=json.loads((root/file).read_text(encoding='utf-8').split('UNI_STATE=')[1].strip())
            return {k:j.get(k) for k in ('flutterViewport','mapViews')}
        except (IndexError,ValueError):return None
    result={'scenario':root.name,'window':{'start':start,'end':end,'seconds':end-start},
            'traceRange':[first,last],'traceCoversAction':first<=start and last>=end,
            'unparsedLines':unparsed,'before':state('before-state.txt'),'after':state('after-state.txt'),
            'layers':frames,'processCpu':process_stats,'threads':threads,'slices':durations,
            'longSlices':sorted([s for s in slice_events if owners.get(s['tid']) in target_pids],key=lambda x:-x['durationMs'])[:60]}
    (root/'analysis.json').write_text(json.dumps(result,ensure_ascii=False,indent=2),encoding='utf-8')
    return result


if __name__=='__main__':
    p=argparse.ArgumentParser();p.add_argument('directories',nargs='+',type=pathlib.Path);args=p.parse_args()
    for directory in args.directories:
        r=analyze(directory)
        print(json.dumps({k:r[k] for k in ('scenario','window','traceCoversAction','layers','processCpu')},ensure_ascii=True))
