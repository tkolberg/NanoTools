#!/bin/bash
#SBATCH --job-name=skim26_k4_diag5
#SBATCH --time=03:00:00
#SBATCH --cpus-per-task=1
#SBATCH --mem=8gb
#SBATCH --output=/blue/avery/tkolberg.fsu/vbs/samples/skim/VBSVVH_skim_2026/tasks/logs/diag5_%j.log
# K4: readability of the 20-file JetMET0 2026B block (runs 402099-402143) with uproot,
# plus a known-good control (2026B file skimmed fine in K2). Requeue-safe.
set -uo pipefail
B=/blue/avery/tkolberg.fsu/vbs/samples/skim/VBSVVH_skim_2026/tasks
D=/home/tkolberg.fsu/vbs/wt/skim26-nanotools/skimmer/condor/skim26
export X509_USER_PROXY=/home/tkolberg.fsu/.x509up_u4924
export X509_CERT_DIR=/cvmfs/cms.cern.ch/grid/etc/grid-security/certificates
export X509_VOMS_DIR=/cvmfs/cms.cern.ch/grid/etc/grid-security/vomsdir
W=${TMPDIR:-/tmp}/diag5_$$; mkdir -p $W
echo "=== skim26 K4 diag5 (uproot read) | job $SLURM_JOB_ID | $(date -Is)"
module load conda >/dev/null 2>&1; eval "$(conda shell.bash hook)"; conda activate vbs-coffea
for lfn in /store/data/Run2026B/JetMET0/NANOAOD/PromptReco-v1/000/402/513/00000/33d6dc82-765b-4eda-9330-1f51cd2b329b.root $(cat $B/block_files.txt); do
  ( cd /home/tkolberg.fsu/vbs/wt/skim26-nanotools/skimmer && source setup.sh el9 >/dev/null && xrdcp -f -s root://cmsxrootd.fnal.gov/$lfn $W/f.root ) || { echo "[read] $(basename $lfn) COPY FAILED"; continue; }
  python -u $D/k4_readcheck.py $W/f.root | sed "s#f.root#$(basename $lfn)#"
  rm -f $W/f.root
done
echo "=== diag5 done $(date -Is)"
