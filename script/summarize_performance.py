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
