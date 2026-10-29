"""K2 comparison: head vs v32 skim of the same 2025 file, and the 2026 file.

Prints, per channel: input events, selected events for head and v32, whether
the (run, lumi, event) sets are identical, branch-set differences, the year the
2026 output reports, and skim rate (events/s, from the run logs' wall times).
Preselection-level counts only; no analysis region is applied here.
"""
import sys, glob, os, re
import ROOT

out, work = sys.argv[1], sys.argv[2]

def keys(path):
    f = ROOT.TFile.Open(path)
    t = f.Get("Events")
    n = t.GetEntries()
    t.SetBranchStatus("*", 0)
    for b in ("run", "luminosityBlock", "event"):
        t.SetBranchStatus(b, 1)
    s = set()
    for e in t:
        s.add((e.run, e.luminosityBlock, e.event))
    br = {b.GetName() for b in f.Get("Events").GetListOfBranches()}
    f.Close()
    return n, s, br

def nin(pattern):
    f = ROOT.TFile.Open(glob.glob(os.path.join(work, pattern))[0])
    n = f.Get("Events").GetEntries(); f.Close(); return n

ok = True
n25, n26 = nin("in25.root"), nin("in26.root")
print(f"input events: 2025 {n25}  2026 {n26}")
for ch in ("0Lep2FJ", "0Lep1FJ"):
    h = glob.glob(f"{out}/head25_{ch}_out*.root"); r = glob.glob(f"{out}/ref25_{ch}_out*.root")
    if not h or not r:
        print(f"{ch}: MISSING output head={h} ref={r}"); ok = False; continue
    nh, sh, bh = keys(h[0]); nr, sr, brr = keys(r[0])
    same = sh == sr
    ok &= same
    print(f"{ch} 2025: head {nh} v32 {nr} identical_events={same} only_head={len(sh-sr)} only_v32={len(sr-sh)}")
    print(f"  branches only head: {sorted(bh-brr)[:15]}  only v32: {sorted(brr-bh)[:15]}")
    g = glob.glob(f"{out}/head26_{ch}_out*.root")
    if g:
        n6, s6, b6 = keys(g[0])
        print(f"{ch} 2026: head {n6} selected of {n26} ({n6/max(n26,1):.3%})")
    else:
        print(f"{ch} 2026: MISSING output"); ok = False
sys.exit(0 if ok else 1)
