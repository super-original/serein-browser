"""RSS and lifetime CPU samples, including newly launched WebKit services.

RSS sums can double-count shared pages. These are not physical-footprint or
energy measurements. Unrelated pre-existing WebKit processes are excluded.
"""
import json,pathlib,re,statistics,sys
root=pathlib.Path(sys.argv[1])
def processes(path):
    rows=[]
    for line in path.read_text().splitlines()[1:]:
        parts=line.strip().split(None,4)
        if len(parts)==5:
            try:rows.append(dict(pid=int(parts[0]),ppid=int(parts[1]),rss_kib=int(parts[2]),cpu_lifetime_percent=float(parts[3]),command=parts[4]))
            except ValueError:pass
    return rows
baseline={r['pid'] for r in processes(root/'process-baseline.txt')}
samples=[]
for p in sorted(root.glob('process-*.txt'),key=lambda p:int(re.search(r'(\d+)\.txt$',p.name)[1]) if re.search(r'(\d+)\.txt$',p.name) else -1):
    if p.name=='process-baseline.txt':continue
    rows=[r for r in processes(p) if r['command'].endswith('/Serein') or ('com.apple.WebKit.' in r['command'] and r['pid'] not in baseline)]
    samples.append(dict(file=p.name,processes=rows,total_rss_mib=sum(r['rss_kib'] for r in rows)/1024,total_cpu_lifetime_percent=sum(r['cpu_lifetime_percent'] for r in rows)))
result={'scope':'Full integration workload including private browsing, diagnostic window, and extension tests; samples every approximately 2 seconds. Not an idle/energy benchmark.','limitations':['RSS may double-count shared pages','CPU is ps lifetime average, not interval CPU','New WebKit services are conservatively attributed by PID difference, not private process APIs','Virtualized CI hardware is not representative of a physical Mac'],'samples':samples}
if samples:result['summary']={'samples':len(samples),'median_rss_mib':statistics.median(s['total_rss_mib'] for s in samples),'peak_rss_mib':max(s['total_rss_mib'] for s in samples),'median_cpu_lifetime_percent':statistics.median(s['total_cpu_lifetime_percent'] for s in samples)}
(root/'performance.json').write_text(json.dumps(result,indent=2))
print(json.dumps(result.get('summary',{}),indent=2))

# TIME is cumulative CPU time; differences over a quiet interval give a
# separate idle measurement instead of relabeling ps lifetime %CPU.
def cpu_seconds(value):
    parts=value.split(':')
    return sum(float(part)*60**i for i,part in enumerate(reversed(parts)))
idle=[]
for p in sorted(root.glob('idle-[0-9]*.txt')):
    rows={}
    for line in p.read_text().splitlines()[1:]:
        values=line.strip().split(None,4)
        if len(values)!=5:continue
        pid=int(values[0]);command=values[4]
        if command.endswith('/Serein') or ('com.apple.WebKit.' in command and pid not in baseline):
            rows[pid]={'rss_kib':int(values[2]),'cpu_seconds':cpu_seconds(values[3]),'command':command}
    idle.append({'time':int(p.stem.split('-')[1]),'processes':rows})
if len(idle)>=2:
    first,last=idle[0],idle[-1]
    elapsed=last['time']-first['time']
    common=set(first['processes']) & set(last['processes'])
    cpu=sum(max(0,last['processes'][pid]['cpu_seconds']-first['processes'][pid]['cpu_seconds']) for pid in common)
    measured={'elapsed_seconds':elapsed,'common_process_count':len(common),'cpu_interval_percent':cpu/elapsed*100,'median_rss_mib':statistics.median(sum(r['rss_kib'] for r in s['processes'].values())/1024 for s in idle),'samples':idle,'limitations':['One short warm-idle interval on a virtualized runner','CPU includes only processes present at both endpoints','WebKit page rendering failure affects workload validity','RSS can double-count shared pages; no energy or physical-footprint claim']}
    (root/'idle-performance.json').write_text(json.dumps(measured,indent=2))
    print('IDLE',json.dumps({k:v for k,v in measured.items() if k!='samples'}))
