#!/bin/bash
#SBATCH --job-name=skim26_k4_rootver
#SBATCH --time=01:30:00
#SBATCH --cpus-per-task=1
#SBATCH --mem=6gb
#SBATCH --output=/blue/avery/tkolberg.fsu/vbs/samples/skim/VBSVVH_skim_2026/tasks/logs/rootver_%j.log
# K4: read 46043e19 (fails at entry 29950 under ROOT 6.36.07, clean in uproot) and a
# control 2026B file with ROOT from three CMSSW releases. Requeue-safe.
set -uo pipefail
D=/home/tkolberg.fsu/vbs/wt/skim26-nanotools/skimmer/condor/skim26
export X509_USER_PROXY=/home/tkolberg.fsu/.x509up_u4924
export X509_CERT_DIR=/cvmfs/cms.cern.ch/grid/etc/grid-security/certificates
export X509_VOMS_DIR=/cvmfs/cms.cern.ch/grid/etc/grid-security/vomsdir
W=${TMPDIR:-/tmp}/rv_$$; mkdir -p $W; cd $W
echo "=== skim26 K4 ROOT-version read test | job $SLURM_JOB_ID | $(date -Is)"
source /cvmfs/cms.cern.ch/cmsset_default.sh
for lfn in /store/data/Run2026B/JetMET0/NANOAOD/PromptReco-v1/000/402/099/00000/46043e19-f064-4728-af8b-9882dab17a9e.root /store/data/Run2026B/JetMET0/NANOAOD/PromptReco-v1/000/402/513/00000/33d6dc82-765b-4eda-9330-1f51cd2b329b.root; do
  b=$(basename $lfn); ( cd /home/tkolberg.fsu/vbs/wt/skim26-nanotools/skimmer && source setup.sh el9 >/dev/null && xrdcp -f -s root://cmsxrootd.fnal.gov/$lfn $W/$b ) || { echo "copy failed $b"; continue; }
  for rel in el9_amd64_gcc13/CMSSW_16_0_0_pre4 el9_amd64_gcc13/CMSSW_16_0_0_pre2 el9_amd64_gcc13/CMSSW_16_1_0_pre2; do
    ( cd /cvmfs/cms.cern.ch/${rel%%/*}/cms/cmssw/${rel#*/}/src && eval $(scramv1 runtime -sh) && cd $W && echo "[$b ${rel#*/}] $(root -l -b -q "$D/k4_rootread.C(\"$W/$b\")" 2>&1 | grep '^\[rootread\]' || echo 'no result (crash)')" )
  done
  rm -f $W/$b
done
echo "=== done $(date -Is)"
