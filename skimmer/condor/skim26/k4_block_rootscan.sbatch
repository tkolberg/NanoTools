#!/bin/bash
#SBATCH --job-name=skim26_k4_rootscan
#SBATCH --time=02:00:00
#SBATCH --cpus-per-task=1
#SBATCH --mem=6gb
#SBATCH --output=/blue/avery/tkolberg.fsu/vbs/samples/skim/VBSVVH_skim_2026/tasks/logs/rootscan_%j.log
# K4: C++ ROOT (6.36.07, the skimmer's) read of all 20 files of the failing JetMET0 2026B
# block; lists entries whose GetEntry fails. Requeue-safe.
set -uo pipefail
B=/blue/avery/tkolberg.fsu/vbs/samples/skim/VBSVVH_skim_2026/tasks
D=/home/tkolberg.fsu/vbs/wt/skim26-nanotools/skimmer/condor/skim26
export X509_USER_PROXY=/home/tkolberg.fsu/.x509up_u4924
export X509_CERT_DIR=/cvmfs/cms.cern.ch/grid/etc/grid-security/certificates
export X509_VOMS_DIR=/cvmfs/cms.cern.ch/grid/etc/grid-security/vomsdir
W=${TMPDIR:-/tmp}/rs_$$; mkdir -p $W; cd $W
echo "=== skim26 K4 block ROOT scan | job $SLURM_JOB_ID | $(date -Is)"
cd /home/tkolberg.fsu/vbs/wt/skim26-nanotools/skimmer && source setup.sh el9 >/dev/null; cd $W
for lfn in $(cat $B/block_files.txt); do
  b=$(basename $lfn)
  xrdcp -f -s root://cmsxrootd.fnal.gov/$lfn $W/$b || { echo "[$b] copy failed"; continue; }
  echo "[$b] $(root -l -b -q "$D/k4_rootread.C(\"$W/$b\")" 2>&1 | grep '^\[rootread\]' || echo 'no result (crash)')"
  rm -f $W/$b
done
echo "=== done $(date -Is)"
