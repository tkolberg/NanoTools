#!/bin/bash
#SBATCH --job-name=skim26_k4_check
#SBATCH --time=01:00:00
#SBATCH --cpus-per-task=1
#SBATCH --mem=4gb
#SBATCH --requeue
#SBATCH --output=/blue/avery/tkolberg.fsu/vbs/samples/skim/VBSVVH_skim_2026/tasks/logs/k4check_%j.log
# K4/K4b: per-task bookkeeping of the whole 2026 JetMET skim against DAS (k4_check.py --das).
# Read-only; requeue-safe.
echo "=== skim26 K4 check | job $SLURM_JOB_ID | $(date -Is)"
export X509_USER_PROXY=/home/tkolberg.fsu/.x509up_u4924
( while sleep 10; do echo "[hb] $(date +%T) k4 check running"; done ) & HB=$!
/home/tkolberg.fsu/envs/vbs-coffea/bin/python /home/tkolberg.fsu/vbs/wt/skim26-nanotools/skimmer/condor/skim26/k4_check.py --das
RC=$?; kill $HB
echo "=== skim26 K4 check done rc=$RC $(date -Is)"
exit $RC
