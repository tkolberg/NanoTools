#!/bin/bash
#SBATCH --job-name=skim26_k4
#SBATCH --array=1-880
#SBATCH --time=04:00:00
#SBATCH --cpus-per-task=1
#SBATCH --mem=2gb
#SBATCH --output=/blue/avery/tkolberg.fsu/vbs/samples/skim/VBSVVH_skim_2026/tasks/logs/task_%a_%A.log
# K4: 2026 JetMET skim, one manifest line per task (0Lep2FJ + 0Lep1FJ, 5 files each).
# The tarball is the one k4_test.sbatch built and tested; requeue-safe per task.
bash /home/tkolberg.fsu/vbs/wt/skim26-nanotools/skimmer/condor/skim26/k4_task.sh $SLURM_ARRAY_TASK_ID
