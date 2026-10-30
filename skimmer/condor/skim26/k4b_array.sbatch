#!/bin/bash
#SBATCH --job-name=skim26_k4b
#SBATCH --array=67-70,190-193
#SBATCH --time=04:00:00
#SBATCH --cpus-per-task=1
#SBATCH --mem=6gb
#SBATCH --requeue
#SBATCH --output=/blue/avery/tkolberg.fsu/vbs/samples/skim/VBSVVH_skim_2026/tasks/logs/task_%a_%A.log
# K4b: rerun the eight tasks of the failing JetMET0 2026B block (runs 402099-402143) with
# every input copied and verified first (k4b_stage.sh); unreadable files dropped and listed.
K4B=1 bash /home/tkolberg.fsu/vbs/wt/skim26-nanotools/skimmer/condor/skim26/k4_task.sh $SLURM_ARRAY_TASK_ID
