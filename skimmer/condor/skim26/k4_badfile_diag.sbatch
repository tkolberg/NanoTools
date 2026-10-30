#!/bin/bash
#SBATCH --job-name=skim26_k4_diag
#SBATCH --time=01:00:00
#SBATCH --cpus-per-task=1
#SBATCH --mem=4gb
#SBATCH --output=/blue/avery/tkolberg.fsu/vbs/samples/skim/VBSVVH_skim_2026/tasks/logs/diag_%j.log
# K4 diagnosis of inputs that crash the skimmer: adler32 of a fresh copy vs DAS,
# and a full read of every Events branch (does ROOT itself fail?). Requeue-safe.
set -uo pipefail
BASE=/blue/avery/tkolberg.fsu/vbs/samples/skim/VBSVVH_skim_2026
export X509_USER_PROXY=/home/tkolberg.fsu/.x509up_u4924
export X509_CERT_DIR=/cvmfs/cms.cern.ch/grid/etc/grid-security/certificates
export X509_VOMS_DIR=/cvmfs/cms.cern.ch/grid/etc/grid-security/vomsdir
cd /home/tkolberg.fsu/vbs/wt/skim26-nanotools/skimmer && source setup.sh el9 >/dev/null
W=${TMPDIR:-/tmp}/diag_$$; mkdir -p $W; cd $W
echo "=== skim26 K4 bad-file diagnosis | job $SLURM_JOB_ID | $(date -Is)"
while read lfn; do
  xrdcp -f -s root://cmsxrootd.fnal.gov/$lfn f.root || xrdcp -f -s root://cms-xrd-global.cern.ch/$lfn f.root || { echo "[file] $lfn COPY FAILED"; continue; }
  echo "[file] $lfn adler32 $(xrdadler32 f.root | cut -d' ' -f1) size $(stat -c %s f.root)"
  python3 - <<'PY'
import ROOT
f = ROOT.TFile.Open("f.root"); t = f.Get("Events"); n = t.GetEntries()
bad = 0
for i in range(0, n, 1):
    if t.GetEntry(i) <= 0:
        bad += 1
        if bad <= 3: print("  bad entry", i)
print(f"  entries {n}, unreadable entries {bad}")
PY
  rm -f f.root
done < $BASE/tasks/bad_files.txt
echo "=== diag done $(date -Is)"
