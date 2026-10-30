"""K4 post-run check of the 2026 JetMET skim (per task, not per dataset).

1. every manifest line has output_N.root and cutflow_N.csv
2. AllEvents == sum of DAS nevents of that task's LFNs (each channel separately)
3. runs_summary eventCount == TheEnd == Events entries in the .root
4. DAS file list per dataset today == manifest (new/invalidated 2026D files)
Prints counts only; the skim has no analysis region, so no blinding concern.
Usage: python k4_check.py [--das]   (env: X509_USER_PROXY; uproot)
"""
import collections, json, os, subprocess, sys
import uproot
BASE = "/blue/avery/tkolberg.fsu/vbs/samples/skim/VBSVVH_skim_2026"
DAS = "/cvmfs/cms.cern.ch/common/dasgoclient"
use_das = "--das" in sys.argv
man = [l.split() for l in open(f"{BASE}/tasks/manifest.txt") if l.strip()]
nev = {}
if use_das:
    for ds in sorted({m[1] for m in man}):
        out = subprocess.run([DAS, f"-query=file dataset=/{ds.replace('_', '/', 2).replace('_NANOAOD', '/NANOAOD')} | grep file.name,file.nevents"],
                             capture_output=True, text=True).stdout.split("\n")
        for l in out:
            p = l.split()
            if len(p) == 2: nev[p[0]] = int(p[1])
bad = collections.Counter(); per_ds = collections.defaultdict(lambda: [0, 0])
for i, (ch, ds, ifile, lfns) in enumerate(man, 1):
    d = f"{BASE}/Run3_Data_v15_2026_{ch}/{ds}"
    root, csv, rs = f"{d}/output_{ifile}.root", f"{d}/cutflow_{ifile}.csv", f"{d}/runs_summary_{ifile}.json"
    if not (os.path.exists(root) and os.path.exists(csv)):
        bad["missing"] += 1; print("MISSING task", i, ch, ds, ifile); continue
    cf = {r.split(",")[0]: float(r.split(",")[1]) for r in open(csv).read().split("\n")[1:] if r}
    nin, nout = int(cf.get("AllEvents", -1)), int(cf.get("TheEnd", -1))
    nroot = uproot.open(root)["Events"].num_entries
    nrs = int(json.load(open(rs))["eventCount"]) if os.path.exists(rs) else -1
    if not (nout == nroot == nrs):
        bad["count"] += 1; print("COUNT task", i, "TheEnd", nout, "root", nroot, "runs_summary", nrs)
    if use_das:
        dfile = f"{d}/dropped_{ifile}.txt"   # K4b: inputs with no readable DAS-matching copy
        dropped = {l.split()[0] for l in open(dfile)} if os.path.exists(dfile) else set()
        if dropped:
            print("DROPPED task", i, ch, ds, ifile, len(dropped), "files", sum(nev.get(f, 0) for f in dropped), "DAS events")
        want = sum(nev.get(f, -10**12) for f in lfns.split(",") if f not in dropped)
        if nin != want:
            bad["input"] += 1; print("INPUT task", i, "AllEvents", nin, "DAS", want)
    per_ds[(ch, ds)][0] += nin; per_ds[(ch, ds)][1] += 1
if use_das:
    for ds in sorted({m[1] for m in man}):
        listed = {f for m in man if m[1] == ds and m[0] == "0Lep2FJ" for f in m[3].split(",")}
        now = {f for f in nev if f"/{ds.split('_')[1].split('-')[0]}/{ds.split('_')[0]}/" in f}
        if listed != now:
            bad["das_drift"] += 1; print("DAS DRIFT", ds, "new", len(now - listed), "gone", len(listed - now))
for (ch, ds), (n, k) in sorted(per_ds.items()):
    print(f"{ch:8s} {ds:42s} tasks {k:4d} input events {n}")
print("K4 CHECK", "PASS" if not bad else f"FAIL {dict(bad)}", f"({len(man)} tasks)")
sys.exit(1 if bad else 0)
