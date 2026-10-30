#!/bin/bash
#SBATCH --job-name=skim26_k4_diag4
#SBATCH --time=03:00:00
#SBATCH --cpus-per-task=1
#SBATCH --mem=4gb
#SBATCH --output=/blue/avery/tkolberg.fsu/vbs/samples/skim/VBSVVH_skim_2026/tasks/logs/diag4_%j.log
# K4: for the two inputs with unreadable baskets, adler32 of copies from two sites
# (FNAL redirector, Nebraska) vs DAS (110bfbfe, e471c0a1), and readability of each.
set -uo pipefail
export X509_USER_PROXY=/home/tkolberg.fsu/.x509up_u4924
export X509_CERT_DIR=/cvmfs/cms.cern.ch/grid/etc/grid-security/certificates
export X509_VOMS_DIR=/cvmfs/cms.cern.ch/grid/etc/grid-security/vomsdir
cd /home/tkolberg.fsu/vbs/wt/skim26-nanotools/skimmer && source setup.sh el9 >/dev/null
W=${TMPDIR:-/tmp}/diag2_$$; mkdir -p $W; cd $W
echo "=== skim26 K4 bad-file diag2 | job $SLURM_JOB_ID | $(date -Is)"
for lfn in $(cat /blue/avery/tkolberg.fsu/vbs/samples/skim/VBSVVH_skim_2026/tasks/block_files.txt); do
 for src in cmsxrootd.fnal.gov; do
  xrdcp -f -s root://$src/$lfn f.root || { echo "[copy] $src $(basename $lfn) FAILED"; continue; }
  echo "[copy] $src $(basename $lfn) size $(stat -c %s f.root)"
  python3 -u -c 'import ROOT;t=ROOT.TFile.Open("f.root").Get("Events");n=t.GetEntries();print("[read] entries",n,"unreadable",sum(1 for i in range(n) if t.GetEntry(i)<=0))' 2>/dev/null | grep "^\[read\]" || echo "[read] ROOT crashed"
  rm -f f.root
 done
done
echo "=== diag2 done $(date -Is)"
