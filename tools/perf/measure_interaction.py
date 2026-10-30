"""Record one observed, bounded interaction on a selected Android 9 device.

Requires PacedInput dex at /data/local/tmp/uni-paced-input.dex for --swipe.
Does not infer gesture ownership: inspect before/after state and screenshots.
"""
import argparse
import json
import pathlib
import shlex
import subprocess
import threading
import time
import zlib


def main():
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument('--adb',required=True)
    p.add_argument('--serial',required=True)
    p.add_argument('--output',type=pathlib.Path,required=True)
    action=p.add_mutually_exclusive_group(required=True)
    action.add_argument('--swipe',type=int,nargs=5,metavar=('X0','Y0','X1','Y1','MS'))
    action.add_argument('--tap',type=int,nargs=2)
    action.add_argument('--idle',type=float)
    p.add_argument('--map-package',default='com.autonavi.amapautp.yh')
    args=p.parse_args()
    if args.swipe and not 16<=args.swipe[4]<=3000: p.error('swipe duration must be 16..3000 ms')
    if args.idle is not None and not 1<=args.idle<=3:p.error('idle duration must be 1..3 s')
    out=args.output;out.mkdir(parents=True,exist_ok=False)
    adb=[args.adb,'-s',args.serial]
    def run(command,timeout=30):
        r=subprocess.run(adb+['shell',command],capture_output=True,timeout=timeout)
        if r.returncode:raise RuntimeError(r.stderr.decode(errors='replace'))
        return r.stdout.decode('utf-8',errors='replace')
    def save(name,command):
        s=run(command);(out/name).write_text(s,encoding='utf-8');return s
    def screenshot(name):
        r=subprocess.run(adb+['exec-out','screencap','-p'],capture_output=True,timeout=30)
        if r.returncode:raise RuntimeError('screencap failed')
        (out/name).write_bytes(r.stdout)
    def state(name):
        return save(name,'dumpsys activity xyz.i4o.uni.launcher/.MainActivity --uni-state')
    state('before-state.txt')
    screenshot('before.png')
    save('threads.txt','ps -A -T')
    layers=save('layers.txt','dumpsys SurfaceFlinger --list').splitlines()
    layers=[s.strip() for s in layers if s.strip().startswith('SurfaceView - ') and
            ('xyz.i4o.uni.launcher/' in s or args.map_package+'/' in s)]
    save('environment.txt','cat /proc/meminfo; cat /sys/class/thermal/thermal_zone*/temp; cat /sys/devices/system/cpu/cpu*/cpufreq/scaling_cur_freq')
    # Android 9 keeps only 128 presents per layer. Poll during the gesture so a
    # 60 Hz run is not silently truncated before the final adb dump completes.
    latency_samples={layer:[] for layer in layers}
    latency_errors=[]
    stop=threading.Event()
    def sample_latency():
        while not stop.is_set():
            for layer in layers:
                try:latency_samples[layer].append(run('dumpsys SurfaceFlinger --latency '+shlex.quote(layer)))
                except Exception as error:latency_errors.append(str(error))
            stop.wait(.6)
    sampler=threading.Thread(target=sample_latency,daemon=True)
    trace_cmd=['exec-out','atrace','-z','-b','16384','-t','5','-a',
               'xyz.i4o.uni.launcher,'+args.map_package,
               'gfx','input','view','sched','freq','idle','binder_driver','dalvik']
    with (out/'interaction.atrace').open('wb') as f:
        trace=subprocess.Popen(adb+trace_cmd,stdout=f,stderr=subprocess.PIPE)
        sampler.start()
        try:
            time.sleep(0.7)
            if args.swipe:
                output=run('CLASSPATH=/data/local/tmp/uni-paced-input.dex app_process /system/bin PacedInput '+
                           ' '.join(map(str,args.swipe)))
            elif args.tap:
                x,y=args.tap
                output=run('CLASSPATH=/data/local/tmp/uni-paced-input.dex app_process /system/bin PacedInput '+
                           f'{x} {y} {x} {y} 50')
            else:
                output=run('cat /proc/uptime; sleep '+str(args.idle)+'; cat /proc/uptime')
            (out/'action.txt').write_text(output,encoding='utf-8')
            time.sleep(0.35)
            _,err=trace.communicate(timeout=45)
        finally:
            stop.set();sampler.join(timeout=35)
            if trace.poll() is None:
                trace.kill();trace.communicate()
    latency={layer:'\n'.join(samples) for layer,samples in latency_samples.items()}
    (out/'latency.json').write_text(json.dumps(latency,indent=2),encoding='utf-8')
    raw=(out/'interaction.atrace').read_bytes()
    decoded=zlib.decompress(raw.split(b'TRACE:',1)[1].lstrip(b'\r\n'))
    (out/'interaction.ftrace').write_bytes(decoded)
    state('after-state.txt');screenshot('after.png')
    metadata={'serial':args.serial,'swipe':args.swipe,'tap':args.tap,'idle':args.idle,
              'mapPackage':args.map_package,'traceCommand':trace_cmd,'traceReturnCode':trace.returncode,
              'traceStderr':err.decode(errors='replace'),'traceBytes':len(decoded),
              'latencyErrors':latency_errors,'latencyPollCounts':{k:len(v) for k,v in latency_samples.items()},
              'limits':['Input is synthetic at 60 Hz; physical touch sampling is not measured.',
                        'Confirm page and map ownership using state and screenshots.',
                        'SF latency buffers may be empty or truncated; never treat missing frames as zero cost.',
                        'CPU scheduling and atrace instrumentation add measurement overhead.']}
    (out/'metadata.json').write_text(json.dumps(metadata,indent=2),encoding='utf-8')
    print(json.dumps({'output':str(out),'action':output,'traceBytes':len(decoded)},ensure_ascii=True),flush=True)


if __name__=='__main__':main()
