#!/bin/bash
# K4: run one manifest line through upstream's slurm_executable.sh.
# Usage: k4_task.sh <task id (1-based manifest line)>
# Requeue-safe: removes this task's output before running; fails on nonzero rc.
set -uo pipefail
ID=$1
BASE=/blue/avery/tkolberg.fsu/vbs/samples/skim/VBSVVH_skim_2026
EXE=/home/tkolberg.fsu/vbs/wt/skim26-nanotools/skimmer/condor/slurm_executable.sh
read -r CH DS IFILE LFNS < <(sed -n "${ID}p" $BASE/tasks/manifest.txt)
[ -n "${LFNS:-}" ] || { echo "no manifest line $ID"; exit 2; }
OUTDIR=$BASE/Run3_Data_v15_2026_${CH}/${DS}
NIN=$(echo $LFNS | tr ',' '\n' | wc -l)
echo "=== skim26 K4 task $ID | $CH $DS output_${IFILE} | $NIN input files | job ${SLURM_ARRAY_JOB_ID:-${SLURM_JOB_ID:-local}}_${SLURM_ARRAY_TASK_ID:-} on $(hostname) | package $(sha1sum $BASE/tasks/package.tar.xz | cut -c1-12) | $(date -Is)"
rm -f $OUTDIR/output_${IFILE}.root $OUTDIR/runs_summary_${IFILE}.json $OUTDIR/cutflow_${IFILE}.*
export X509_USER_PROXY=/home/tkolberg.fsu/.x509up_u4924
W=${TMPDIR:-/tmp}/sk26_${ID}_$$; mkdir -p $W && cd $W && cp $BASE/tasks/package.tar.xz package.tar.gz
# heartbeat: bytes copied in and written out
( while sleep 10; do echo "[hb] $(date +%T) task $ID in $(du -sm $W/data 2>/dev/null | cut -f1) MB, out $(du -cm $W/CMSSW_*/output*.root 2>/dev/null | tail -1 | cut -f1) MB"; done ) & HB=$!
t0=$(date +%s)
bash $EXE $OUTDIR output "$LFNS" $IFILE CMSSW_16_0_0_pre4 el9_amd64_gcc13 -d ./ -a $CH -t Events -T Events 2>&1 \
    | grep -v -E '^\[DEBUG\]|^[[:space:]]*$'
RC=${PIPESTATUS[0]}
kill $HB 2>/dev/null
[ $RC -eq 0 ] && [ ! -s $OUTDIR/output_${IFILE}.root ] && { echo "rc 0 but no output"; RC=4; }
# events in / selected, from the merged cutflow (AllEvents is checked against DAS nevents)
N=$(awk -F, '$1=="AllEvents"{i=$2} $1=="TheEnd"{o=$2} END{printf "%d/%d", i, o}' $OUTDIR/cutflow_${IFILE}.csv 2>/dev/null)
echo "=== skim26 K4 task $ID done rc=$RC in/selected=$N wall=$(( $(date +%s) - t0 ))s $(date -Is)"
rm -rf $W
exit $RC
