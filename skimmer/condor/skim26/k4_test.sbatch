#!/bin/bash
#SBATCH --job-name=skim26_k4_test
#SBATCH --time=02:00:00
#SBATCH --cpus-per-task=2
#SBATCH --mem=4gb
#SBATCH --output=/blue/avery/tkolberg.fsu/vbs/samples/skim/VBSVVH_skim_2026/tasks/logs/test_%j.log
# K4 test: build the skim tarball from this tree, then run manifest task 1
# through upstream's slurm_executable.sh. Requeue-safe (rebuilds, task clears its output).
set -uo pipefail
C=/home/tkolberg.fsu/vbs/wt/skim26-nanotools/skimmer/condor
BASE=/blue/avery/tkolberg.fsu/vbs/samples/skim/VBSVVH_skim_2026
echo "=== skim26 K4 build+test | job $SLURM_JOB_ID | tree $(git -C $C rev-parse --short HEAD)$(git -C $C diff --quiet HEAD -- ../src ../../NanoCORE || echo +dirty) | $(date -Is)"
( cd $C/.. && source setup.sh el9 >/dev/null && cd condor && bash ./maketar.sh > $BASE/tasks/maketar.log 2>&1 ) || { echo "MAKETAR FAILED"; tail -20 $BASE/tasks/maketar.log; exit 2; }
command cp -f $C/package.tar.xz $BASE/tasks/package.tar.xz
tar tJf $BASE/tasks/package.tar.xz | head -5; echo "package $(sha1sum $BASE/tasks/package.tar.xz | cut -c1-12)"
bash $C/skim26/k4_task.sh 1
