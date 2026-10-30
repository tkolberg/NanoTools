#!/bin/bash
# K4b: copy each input LFN to a local dir and accept it only if its adler32 equals DAS
# and every Events entry reads in ROOT (k4_rootread.C). Sources tried in order: FNAL, UNL,
# global redirector, then every replica the global redirector locates.
# Usage: k4b_stage.sh <stage dir> <comma-separated LFNs> <good list out> <dropped list out>
# A file with no good copy is listed in <dropped list out> (LFN + why); rc 0 unless setup fails.
set -uo pipefail
STAGE=$1; LFNS=$2; GOOD=$3; DROP=$4
D=/home/tkolberg.fsu/vbs/wt/skim26-nanotools/skimmer/condor/skim26
ADLER=/blue/avery/tkolberg.fsu/vbs/samples/skim/VBSVVH_skim_2026/tasks/block_das_adler.txt
export X509_CERT_DIR=/cvmfs/cms.cern.ch/grid/etc/grid-security/certificates
export X509_VOMS_DIR=/cvmfs/cms.cern.ch/grid/etc/grid-security/vomsdir
cd /home/tkolberg.fsu/vbs/wt/skim26-nanotools/skimmer && source setup.sh el9 >/dev/null || exit 3
mkdir -p $STAGE; : > $GOOD; : > $DROP
for lfn in ${LFNS//,/ }; do
  b=$(basename $lfn); dest=$STAGE/$b
  want=$(awk -v b=$b '$1==b{print $2}' $ADLER)
  [ -n "$want" ] || { echo "[stage] $b: no DAS adler32 in $ADLER"; exit 3; }
  want=$(printf '%08x' 0x$want)
  srcs="root://cmsxrootd.fnal.gov/ root://xrootd.unl.edu/ root://cms-xrd-global.cern.ch/"
  srcs+=" $(xrdfs cms-xrd-global.cern.ch locate -d -m $lfn 2>/dev/null | awk '{print "root://"$1"/"}' | sort -u | tr '\n' ' ')"
  ok=0; why=""
  for s in $srcs; do
    rm -f $dest
    xrdcp -f -s $s$lfn $dest 2>/dev/null || { why+=" ${s}:copy"; continue; }
    got=$(python3 $D/adler32.py $dest)
    [ "$got" == "$want" ] || { why+=" ${s}:adler=$got"; continue; }
    rr=$(root -l -b -q "$D/k4_rootread.C(\"$dest\")" 2>&1 | grep '^\[rootread\]')
    # a copy that matches DAS byte-for-byte but does not read is bad at origin: every
    # other DAS-matching replica is the same bytes, so stop here
    [[ "$rr" == *" bad 0 "* ]] || { why+=" ${s}:read(${rr:-crash}) bad-at-origin"; break; }
    echo "[stage] $b OK from $s ($rr)"; ok=1; break
  done
  if [ $ok -eq 1 ]; then echo $dest >> $GOOD
  else rm -f $dest; echo "$lfn$why" >> $DROP; echo "[stage] $b DROPPED:$why"; fi
done
exit 0
