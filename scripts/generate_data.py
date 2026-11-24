"""Generate a fully synthetic dataset for Halden Networks, a fictional IoT / telecom
managed-services operator. No real company, customer or vendor data is used.
Run: python scripts/generate_data.py   (writes CSVs to data/)"""
import csv, random, math, os
from datetime import datetime, timedelta

random.seed(42)
OUT = os.path.join(os.path.dirname(__file__), '..', 'data')
START, END = datetime(2025, 1, 1), datetime(2026, 6, 30, 23, 59)
RCA_PROGRAMME = datetime(2025, 10, 1)      # root-cause programme starts
P2P_REDESIGN = datetime(2025, 7, 1)        # PO approval process redesigned

def w(name, header, rows):
    with open(os.path.join(OUT, name), 'w', newline='') as f:
        c = csv.writer(f); c.writerow(header); c.writerows(rows)

# ---------- projects ----------
programmes = [('Smart Metering', 'Utilities'), ('Public Safety IoT', 'Government'),
              ('Smart Buildings', 'Enterprise'), ('Fleet Telematics', 'Enterprise')]
districts = ['North', 'South', 'East', 'West', 'Central']
projects = []
pid = 1
for prog, seg in programmes:
    for d in districts:
        golive = datetime(2023, 1, 1) + timedelta(days=random.randint(0, 600))
        devices = random.choice([800, 1200, 2500, 4000, 6000])
        projects.append((pid, f'{prog} - {d}', prog, seg, golive.date(), devices)); pid += 1
w('projects.csv', ['project_id', 'project_name', 'programme', 'customer_segment', 'go_live_date', 'device_count'], projects)

# ---------- vendors ----------
cats = ['Field Maintenance'] * 7 + ['Network Services'] * 6 + ['Hardware Supply'] * 5 + ['Software Platform'] * 4 + ['Facilities'] * 3
names = ['Arkwell', 'Brightline', 'Cobaltis', 'Dunmore', 'Everfield', 'Fenwick', 'Galloway', 'Harrowgate', 'Ironbay', 'Juniper Ridge',
         'Kestrel', 'Larkspur', 'Meridian Arc', 'Northgate', 'Oakhurst', 'Pinecrest', 'Quayside', 'Redstone', 'Silverlake', 'Thornbury',
         'Upland', 'Valemont', 'Westbrook', 'Yarrow', 'Zephyr']
vendors, vq = [], {}
for i, (n, c) in enumerate(zip(names, cats), start=1):
    tier = random.choices(['Strategic', 'Preferred', 'Tactical'], [0.3, 0.4, 0.3])[0]
    vendors.append((i, f'{n} {"Services" if c != "Hardware Supply" else "Supply"}', c, tier, random.choice([30, 45, 60])))
    vq[i] = random.choice([0.75, 0.9, 1.0, 1.0, 1.1, 1.25, 1.5])   # >1 = slower than target
vq[4], vq[17] = 1.7, 1.6   # two clearly weak vendors
vq[2], vq[11] = 0.7, 0.72  # two strong ones
w('vendors.csv', ['vendor_id', 'vendor_name', 'category', 'contract_tier', 'payment_terms_days'], vendors)

# ---------- SLA policy ----------
sla = [('P1', 15, 4), ('P2', 30, 8), ('P3', 120, 24), ('P4', 480, 72)]
w('sla_policy.csv', ['priority', 'response_target_min', 'resolution_target_hrs'], sla)
slad = {p: (r, h) for p, r, h in sla}

# ---------- incidents ----------
inc_cats = ['Sensor offline', 'Gateway down', 'Power failure', 'Connectivity loss', 'Software fault', 'Physical damage', 'Configuration error']
service_vendors = [v[0] for v in vendors if v[2] in ('Field Maintenance', 'Network Services', 'Software Platform')]
proj_vendor = {p[0]: random.sample(service_vendors, 3) for p in projects}
# a few project/category pairs with a chronic repeat problem (fixed by the RCA programme)
assets = {p[0]: [p[0] * 1000 + k for k in range(1, p[5] // 10 + 1)] for p in projects}   # one asset = one site/gateway cluster
chronic = set(random.sample([a for p in projects for a in assets[p[0]]], 60))           # assets with a chronic fault

incidents = []
iid = 1
def make_incident(opened, proj, asset, cat, vendor, prio):
    global iid
    r_t, h_t = slad[prio]
    f = vq[vendor] * (0.9 if opened >= RCA_PROGRAMME else 1.0)
    resp = max(1, random.lognormvariate(math.log(r_t * 0.55 * f), 0.55))
    res_h = max(0.2, random.lognormvariate(math.log(h_t * 0.5 * f), 0.6))
    responded = opened + timedelta(minutes=resp)
    resolved = opened + timedelta(hours=res_h)
    if resolved > END and random.random() < 0.7: resolved = None   # still open at extract time
    row = [iid, opened.strftime('%Y-%m-%d %H:%M:%S'), proj, asset, vendor, prio, cat,
           responded.strftime('%Y-%m-%d %H:%M:%S'), resolved.strftime('%Y-%m-%d %H:%M:%S') if resolved else '']
    iid += 1
    incidents.append(row)
    return resolved

day = START
while day <= END:
    season = 1.25 if day.month in (6, 7, 8) else 1.0
    for p in projects:
        lam = p[5] / 1000 * 0.33 * season
        for _ in range(sum(1 for _ in range(12) if random.random() < lam / 12)):
            opened = day + timedelta(minutes=random.randint(0, 1439))
            cat = random.choice(inc_cats)
            asset = random.choice(assets[p[0]])
            prio = random.choices(['P1', 'P2', 'P3', 'P4'], [0.03, 0.12, 0.45, 0.40])[0]
            vendor = random.choice(proj_vendor[p[0]])
            resolved = make_incident(opened, p[0], asset, cat, vendor, prio)
            # repeats: same project + category comes back within a few days
            rep_p = 0.12
            if asset in chronic: rep_p = 0.8 if opened < RCA_PROGRAMME else 0.2
            elif opened >= RCA_PROGRAMME: rep_p = 0.06
            t = resolved or opened
            while random.random() < rep_p and t < END - timedelta(days=7):
                t = t + timedelta(hours=random.randint(6, 140))
                make_incident(t, p[0], asset, cat, vendor, prio)
                rep_p *= 0.6
    day += timedelta(days=1)
incidents.sort(key=lambda r: r[1])
for n, r in enumerate(incidents, 1): r[0] = n
w('incidents.csv', ['incident_id', 'opened_at', 'project_id', 'asset_id', 'vendor_id', 'priority', 'category', 'responded_at', 'resolved_at'], incidents)

# ---------- purchase orders & invoices ----------
pos, invs = [], []
po_id, inv_id = 1, 1
for v in vendors:
    n_po = random.randint(40, 110) if v[3] != 'Tactical' else random.randint(15, 45)
    scale = {'Hardware Supply': 18000, 'Network Services': 9000, 'Field Maintenance': 6000, 'Software Platform': 12000, 'Facilities': 4000}[v[2]]
    if v[0] in (1, 6, 12, 19): scale *= 3.5     # a few very large suppliers (Pareto)
    for _ in range(n_po):
        created = START + timedelta(days=random.randint(0, 520), hours=random.randint(8, 17))
        amount = round(random.lognormvariate(math.log(scale), 0.7), 2)
        base = 6.5 if created < P2P_REDESIGN else 2.5
        appr_days = max(0.2, random.lognormvariate(math.log(base * (1.4 if amount > 25000 else 1)), 0.5))
        approved = created + timedelta(days=appr_days)
        status = random.choices(['Closed', 'Open', 'Cancelled'], [0.85, 0.1, 0.05])[0]
        proj = random.choice(projects)[0]
        pos.append([po_id, v[0], proj, created.strftime('%Y-%m-%d %H:%M:%S'), approved.strftime('%Y-%m-%d %H:%M:%S'), amount, status])
        if status != 'Cancelled':
            parts = 2 if random.random() < 0.15 else 1
            for k in range(parts):
                received = approved + timedelta(days=random.randint(5, 40) + 20 * k)
                if received > END: continue
                inv_amt = round(amount / parts * (random.uniform(1.03, 1.12) if random.random() < 0.05 else 1), 2)
                ap_days = random.lognormvariate(math.log(7 if created < P2P_REDESIGN else 4), 0.5)
                inv_approved = received + timedelta(days=ap_days)
                due = received + timedelta(days=v[4])
                paid = inv_approved + timedelta(days=random.randint(5, v[4] + 12))
                paid_s = paid.strftime('%Y-%m-%d') if paid <= END else ''
                invs.append([inv_id, po_id, received.strftime('%Y-%m-%d'), inv_approved.strftime('%Y-%m-%d'), due.strftime('%Y-%m-%d'), paid_s, inv_amt])
                inv_id += 1
        po_id += 1
w('purchase_orders.csv', ['po_id', 'vendor_id', 'project_id', 'created_at', 'approved_at', 'po_amount', 'status'], pos)
w('invoices.csv', ['invoice_id', 'po_id', 'received_date', 'approved_date', 'due_date', 'paid_date', 'invoice_amount'], invs)
print(len(projects), 'projects', len(vendors), 'vendors', len(incidents), 'incidents', len(pos), 'POs', len(invs), 'invoices')
