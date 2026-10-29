"""K4: task manifest for the 2026 JetMET skim array.

One line per array task: <channel> <dataset_flat> <ifile> <comma-separated LFNs>.
Files are grouped FILES_PER_TASK per output, per dataset, in DAS order; ifile is
1-based within (channel, dataset), as the Metis output_N.root naming.
"""
import os, subprocess, sys
FILES_PER_TASK = 5
DAS = "/cvmfs/cms.cern.ch/common/dasgoclient"
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
DATASETS = [f"/{pd}/Run2026{e}-PromptReco-v1/NANOAOD" for pd in ("JetMET0", "JetMET1") for e in "ABD"]
out = sys.argv[1]
lines, nfiles = [], 0
for ds in DATASETS:
    lfns = sorted(l.strip() for l in subprocess.run([DAS, f"-query=file dataset={ds}"], capture_output=True,
                                                     text=True, check=True).stdout.split() if l.strip().endswith(".root"))
    assert lfns, ds
    nfiles += len(lfns)
    flat = ds.replace("/", "_").lstrip("_")
    for ch in ("0Lep2FJ", "0Lep1FJ"):
        for i in range(0, len(lfns), FILES_PER_TASK):
            lines.append(f"{ch} {flat} {i // FILES_PER_TASK + 1} {','.join(lfns[i:i + FILES_PER_TASK])}")
    print(ds, len(lfns), "files")
open(out, "w").write("\n".join(lines) + "\n")
print(f"{nfiles} files, {len(lines)} tasks -> {out}")
