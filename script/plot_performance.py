#!/usr/bin/env python3
"""Plot existing runner evidence; optional analysis tool, not a CI dependency."""
import argparse
import csv
import json
import os
import pathlib
import statistics
import tempfile
from sample_owned_processes import interval_cpu

parser = argparse.ArgumentParser()
parser.add_argument('samples', type=pathlib.Path)
parser.add_argument('output', type=pathlib.Path)
parser.add_argument('--commit', required=True)
args = parser.parse_args()
samples = [json.loads(line) for line in args.samples.read_text().splitlines() if line.strip()]
assert len(samples) > 1
args.output.mkdir(parents=True, exist_ok=True)
rows = []
for index, sample in enumerate(samples):
    totals = {kind: sum(p['rss_kib'] for p in sample['processes'] if p['ownership'] == kind)/1024
              for kind in ('confirmed', 'unresolved', 'foreign')}
    interval = interval_cpu(samples[index-1], sample) if index else None
    rows.append(dict(seconds=sample['monotonic_seconds']-samples[0]['monotonic_seconds'],
                     confirmed_rss_mib=totals['confirmed'], unresolved_rss_mib=totals['unresolved'],
                     foreign_rss_mib=totals['foreign'], idle=sample['idle'],
                     cpu_interval_percent=interval['cpu_interval_percent'] if interval else None,
                     interval_processes=interval['common_process_count'] if interval else None))
with (args.output/'samples.csv').open('w', newline='') as output:
    writer = csv.DictWriter(output, fieldnames=rows[0].keys());writer.writeheader();writer.writerows(rows)
idle_samples = [s for s in samples if s['idle']]
summary = dict(commit=args.commit, samples=len(samples),
               confirmed_median_rss_mib=statistics.median(r['confirmed_rss_mib'] for r in rows),
               unresolved_peak_rss_mib=max(r['unresolved_rss_mib'] for r in rows))
if len(idle_samples) >= 2:
    summary['idle_interval'] = interval_cpu(idle_samples[0], idle_samples[-1])
    summary['idle_confirmed_median_rss_mib'] = statistics.median(r['confirmed_rss_mib'] for r in rows if r['idle'])
    summary['idle_unresolved_peak_rss_mib'] = max(r['unresolved_rss_mib'] for r in rows if r['idle'])
(args.output/'summary.json').write_text(json.dumps(summary, indent=2)+'\n')
with tempfile.TemporaryDirectory(prefix='serein-plot-config-') as cache:
    os.environ['MPLCONFIGDIR'] = cache
    os.environ['XDG_CACHE_HOME'] = cache
    import matplotlib
    matplotlib.use('Agg')
    import matplotlib.pyplot as plt
    figure, axes = plt.subplots(2, 1, figsize=(10, 6.8), sharex=True, gridspec_kw={'height_ratios': [1.3, 1]})
    elapsed = [r['seconds'] for r in rows]
    axes[0].plot(elapsed, [r['confirmed_rss_mib'] for r in rows], color='#168582', label='Confirmed Serein + WebKit RSS')
    axes[0].plot(elapsed, [r['unresolved_rss_mib'] for r in rows], color='#ad4b63', linestyle='--', label='Unresolved WebKit RSS (separate)')
    axes[0].set_ylabel('RSS sum (MiB)');axes[0].set_ylim(bottom=0);axes[0].legend(loc='upper left', fontsize=9)
    axes[1].plot(elapsed, [r['cpu_interval_percent'] for r in rows], color='#405878')
    axes[1].set_ylabel('Interval CPU (% of one core)');axes[1].set_xlabel('Seconds since first sample (after app launch)');axes[1].set_ylim(bottom=0)
    idle_rows = [r for r in rows if r['idle']]
    for axis in axes:
        if len(idle_rows) >= 2:
            axis.axvspan(idle_rows[0]['seconds'], idle_rows[-1]['seconds'], color='#bfc4c7', alpha=.3)
        axis.grid(alpha=.2);axis.spines[['top', 'right']].set_visible(False)
    if idle_rows:
        axes[1].text(idle_rows[0]['seconds'], axes[1].get_ylim()[1]*.92, 'Idle fixture', fontsize=9)
    figure.suptitle(f'Serein CI integration workload · macOS 27 ARM64 · {args.commit[:7]}', fontsize=14)
    figure.text(.09,.025,'One virtualized run; desktop WebKit content was blank. RSS can double-count shared pages.\nCPU includes only confirmed process identities present at both interval endpoints; diagnostic overhead applies.',fontsize=9,color='#505050')
    figure.tight_layout(rect=(0,.08,1,.95))
    figure.savefig(args.output/'performance.png', dpi=150)
    plt.close(figure)
print(json.dumps(summary, indent=2))
