#!/bin/bash
#SBATCH --job-name=skim26_k2_smoke
#SBATCH --time=03:00:00
#SBATCH --cpus-per-task=4
#SBATCH --mem=8gb
#SBATCH --output=/blue/avery/tkolberg.fsu/vbs/samples/skim/skim26_smoke/logs/k2_%j.log
# K2 smoke: build the head (2026) and v32 skimmers, skim one 2025 JetMET file
# with both (equivalence), one 2026 file with head (year + timing).
# Requeue-safe: clears its own outputs on start.
set -uo pipefail
HEAD=/home/tkolberg.fsu/vbs/wt/skim26-nanotools
REF=/home/tkolberg.fsu/vbs/wt/skim26-nanotools-v32ref
OUT=/blue/avery/tkolberg.fsu/vbs/samples/skim/skim26_smoke
F25=/store/data/Run2025D/JetMET0/NANOAOD/PromptReco-v1/000/395/750/00000/f410569b-bd3b-40ed-8d1f-21ab57f39471.root
F26=/store/data/Run2026B/JetMET0/NANOAOD/PromptReco-v1/000/402/513/00000/33d6dc82-765b-4eda-9330-1f51cd2b329b.root
export X509_USER_PROXY=/home/tkolberg.fsu/.x509up_u4924
export X509_CERT_DIR=/cvmfs/cms.cern.ch/grid/etc/grid-security/certificates
export X509_VOMS_DIR=/cvmfs/cms.cern.ch/grid/etc/grid-security/vomsdir
echo "=== skim26 K2 smoke | job ${SLURM_JOB_ID:-local} on $(hostname) | head $(git -C $HEAD rev-parse --short HEAD)$(git -C $HEAD diff --quiet || echo +dirty) ref $(git -C $REF rev-parse --short HEAD) | $(date -Is)"
rm -rf $OUT/k2 && mkdir -p $OUT/k2
W=${TMPDIR:-/tmp}/k2_$$; mkdir -p $W && cd $W
for T in $HEAD $REF; do
  ( cd $T/skimmer && source setup.sh el9 >/dev/null && make -j4 >make.log 2>&1 ) || { echo "BUILD FAILED $T"; tail -20 $T/skimmer/make.log; exit 2; }
  echo "[build] ok $T"
done
source /cvmfs/cms.cern.ch/cmsset_default.sh
for pair in "in25:$F25" "in26:$F26"; do
  n=${pair%%:*}; f=${pair#*:}
  # keep the /store-relative path: the skimmer parses the year from it (as slurm_executable.sh)
  rel=${f#/store/}; mkdir -p $W/$(dirname $rel)
  for r in cmsxrootd.fnal.gov cms-xrd-global.cern.ch; do
    ( cd $HEAD/skimmer && source setup.sh el9 >/dev/null && xrdcp -f -s root://$r/$f $W/$rel && ln -sfn $W/$rel $W/$n.root ) && break
  done
done
ls -la $W/in25.root $W/in26.root || { echo "INPUT COPY FAILED"; exit 3; }
# heartbeat: output size every 10 s
( while sleep 10; do echo "[hb] $(date +%T) outputs: $(du -cm $W/*/out*.root 2>/dev/null | tail -1)"; done ) & HB=$!
run() { # tag tree input chan  -- own dir with the tree's data/ (as the job tarball)
  local d=$W/$1; mkdir -p $d && cd $d && ln -sfn $2/skimmer/data data
  local t0=$(date +%s)
  ( cd $2/skimmer && source setup.sh el9 >/dev/null; cd $d && $2/skimmer/skim $(readlink -f $W/$3) -n out -d ./ -a $4 -t Events -T Events > $d/skim.log 2>&1 ); local rc=$?
  echo "[run] $1 rc=$rc wall=$(( $(date +%s) - t0 ))s year: $(grep -i -m1 -o 'year[^,;]*' $d/skim.log)"
  tail -3 $d/skim.log; cd $W
}
for ch in 0Lep2FJ 0Lep1FJ; do
  run head25_$ch $HEAD in25.root $ch
  run ref25_$ch  $REF  in25.root $ch
  run head26_$ch $HEAD in26.root $ch
done
kill $HB
for d in $W/*_0Lep*; do t=$(basename $d); cp $d/out*.root $OUT/k2/${t}_out.root; cp $d/skim.log $OUT/k2/${t}.log; done
cd $HEAD/skimmer && source setup.sh el9 >/dev/null
python3 $HEAD/skimmer/condor/skim26/k2_compare.py $OUT/k2 $W; rc=$?
echo "=== skim26 K2 smoke done rc=$rc $(date -Is)"
exit $rc
