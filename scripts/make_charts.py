"""Charts for the README, built from the query results in results/ (run scripts/run_all.sh first)."""
import csv, os
from collections import defaultdict
import matplotlib.pyplot as plt
import matplotlib.dates as mdates
from datetime import date

ROOT = os.path.join(os.path.dirname(__file__), '..')
def rows(name): return list(csv.DictReader(open(os.path.join(ROOT, 'results', name + '.csv'))))
INK, MUTED, ACCENT, GRID = '#1f2933', '#7b8794', '#2f6fde', '#e4e7eb'
plt.rcParams.update({'font.family': 'DejaVu Sans', 'font.size': 10, 'axes.edgecolor': GRID, 'axes.labelcolor': MUTED,
                     'xtick.color': MUTED, 'ytick.color': MUTED, 'axes.spines.top': False, 'axes.spines.right': False})

# 1) PO approval time before / after the process redesign
r = rows('06_p2p_cycle_time')
x = [date.fromisoformat(d['month']) for d in r]; y = [float(d['median_po_approval_days']) for d in r]
fig, ax = plt.subplots(figsize=(8, 3.6), dpi=150)
ax.plot(x, y, color=ACCENT, lw=2.2, marker='o', ms=4)
ax.axvline(date(2025, 7, 1), color=MUTED, ls='--', lw=1)
ax.text(date(2025, 7, 8), max(y) * 0.95, 'Process redesign\n(Jul 2025)', color=MUTED, fontsize=9, va='top')
ax.set_ylim(0, max(y) * 1.15); ax.set_ylabel('Median days to approve a PO'); ax.grid(axis='y', color=GRID)
ax.xaxis.set_major_formatter(mdates.DateFormatter('%b %y'))
ax.set_title('PO approval time dropped from ~7 days to under 3', loc='left', color=INK, fontsize=12, fontweight='bold')
fig.tight_layout(); fig.savefig(os.path.join(ROOT, 'images', 'po_approval_days.png'))

# 2) Vendor scorecard: resolution SLA, 2026 H1
r = rows('09_vendor_scorecard')
r.sort(key=lambda d: float(d['resolution_sla_pct']))
names = [d['vendor_name'].replace(' Services', '') for d in r]; vals = [float(d['resolution_sla_pct']) for d in r]
fig, ax = plt.subplots(figsize=(8, 5), dpi=150)
colors = [ACCENT if v >= 90 else '#c5221f' for v in vals]
ax.barh(names, vals, color=colors, height=0.65)
ax.axvline(90, color=MUTED, ls='--', lw=1); ax.text(90.5, -0.9, '90% target', color=MUTED, fontsize=9)
for i, v in enumerate(vals): ax.text(v + 0.6, i, f'{v:.0f}%', va='center', fontsize=8.5, color=INK)
ax.set_xlim(0, 105); ax.set_xlabel('Incidents resolved within SLA (%), Jan-Jun 2026'); ax.grid(axis='x', color=GRID)
below = sum(v < 90 for v in vals)
words = {1:'One vendor sits',2:'Two vendors sit',3:'Three vendors sit',4:'Four vendors sit',5:'Five vendors sit',6:'Six vendors sit'}
ax.set_title(f"{words.get(below, str(below) + ' vendors sit')} below the 90% resolution target", loc='left', color=INK, fontsize=12, fontweight='bold')
fig.tight_layout(); fig.savefig(os.path.join(ROOT, 'images', 'vendor_resolution_sla.png'))
print('charts written to images/')
