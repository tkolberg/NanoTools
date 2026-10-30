#!/bin/bash

OUTPUTDIR=$1
OUTPUTNAME=$2
INPUTFILENAMES=$3
IFILE=$4
CMSSWVERSION=$5
SCRAMARCH=$6
shift 6
CMDLINE_EXTRAARGS="$@"

MAX_RETRIES=6
RETRY_SLEEP=30

# If a proxy file was staged into the working directory (e.g. by SLURM wrapper), use it
if [ -f x509up_proxy ] && [ -z "${X509_USER_PROXY}" ]; then
    export X509_USER_PROXY=$(pwd)/x509up_proxy
    echo "[proxy] Using staged proxy: ${X509_USER_PROXY}"
fi

# Grid CA + VOMS dirs (matches the hpggsetup* aliases in ~/dot/mybashrc).
# Required for xrootd GSI server-cert verification — without these the new
# xrootd 5.x client falls back to ztn and fails "non-TLS" auth, killing xrdcp.
export X509_CERT_DIR=/cvmfs/cms.cern.ch/grid/etc/grid-security/certificates
export X509_VOMS_DIR=/cvmfs/cms.cern.ch/grid/etc/grid-security/vomsdir

function getjobad {
    grep -i "^$1" "$_CONDOR_JOB_AD" | cut -d= -f2- | xargs echo
}
function setup_chirp {
    if [ -e ./condor_chirp ]; then
    # Note, in the home directory
        mkdir chirpdir
        mv condor_chirp chirpdir/
        export PATH="$PATH:$(pwd)/chirpdir"
        echo "[chirp] Found and put condor_chirp into $(pwd)/chirpdir"
    elif [ -e /usr/libexec/condor/condor_chirp ]; then
        export PATH="$PATH:/usr/libexec/condor"
        echo "[chirp] Found condor_chirp in /usr/libexec/condor"
    else
        echo "[chirp] No condor_chirp :("
    fi
}
function chirp {
    # Note, $1 (the classad name) must start with Chirp
    condor_chirp set_job_attr_delayed $1 $2
    ret=$?
    echo "[chirp] Chirped $1 => $2 with exit code $ret"
}

# Inputs already on this node (an existing local path) are read in place, like /cmsuf ones.
LOCAL_INPUTS=0
[[ ${INPUTFILENAMES} == /cmsuf/* || -f ${INPUTFILENAMES%%,*} ]] && LOCAL_INPUTS=1
if [ ${LOCAL_INPUTS} -eq 0 ]; then
    INPUTFILENAMES=${INPUTFILENAMES//\/store/root:\/\/cmsxrootd.fnal.gov\/\/store}
fi

# Make sure OUTPUTNAME doesn't have .root since we add it manually
OUTPUTNAME=$(echo $OUTPUTNAME | sed 's/\.root//')

setup_chirp

echo -e "\n--- begin header output ---\n" #                     <----- section division
echo "OUTPUTDIR: $OUTPUTDIR"
echo "OUTPUTNAME: $OUTPUTNAME"
echo "INPUTFILENAMES: $INPUTFILENAMES"
echo "IFILE: $IFILE"
echo "CMSSWVERSION: $CMSSWVERSION"
echo "SCRAMARCH: $SCRAMARCH"

echo "GLIDEIN_CMSSite: $GLIDEIN_CMSSite"
echo "hostname: $(hostname)"
echo "uname -a: $(uname -a)"
echo "time: $(date +%s)"
echo "pwd: $(pwd)"
echo "df -h .: $(df -h . | tail -1)"
echo "args: $@"

echo -e "\n--- end header output ---\n" #                       <----- section division

if [ -r "$OSGVO_CMSSW_Path"/cmsset_default.sh ]; then
    echo "sourcing environment: source $OSGVO_CMSSW_Path/cmsset_default.sh"
    source "$OSGVO_CMSSW_Path"/cmsset_default.sh
elif [ -r "$OSG_APP"/cmssoft/cms/cmsset_default.sh ]; then
    echo "sourcing environment: source $OSG_APP/cmssoft/cms/cmsset_default.sh"
    source "$OSG_APP"/cmssoft/cms/cmsset_default.sh
elif [ -r /cvmfs/cms.cern.ch/cmsset_default.sh ]; then
    echo "sourcing environment: source /cvmfs/cms.cern.ch/cmsset_default.sh"
    source /cvmfs/cms.cern.ch/cmsset_default.sh
else
    echo "ERROR! Couldn't find $OSGVO_CMSSW_Path/cmsset_default.sh or /cvmfs/cms.cern.ch/cmsset_default.sh or $OSG_APP/cmssoft/cms/cmsset_default.sh"
    exit 1
fi

export SCRAM_ARCH=${SCRAMARCH}

scramv1 project CMSSW $CMSSWVERSION
cd $CMSSWVERSION
eval $(scramv1 runtime -sh)
mv ../package.tar.gz package.tar.gz
tar xf package.tar.gz

if [[ ${INPUTFILENAMES} == *"ULSignalSamples"* ]]; then
    :
elif [ ${LOCAL_INPUTS} -eq 1 ]; then
    # Local files on shared filesystem — just convert commas to spaces
    INPUTFILENAMES=${INPUTFILENAMES//,/ }
    echo "Using local files (no xrdcp needed): ${INPUTFILENAMES}"
else
    ##########################################################
    #UNCOMMENT TO COPY FAILING FILES DIRECTLY TO CONDOR NODE
    echo "Before XRootD copy"
    echo INPUTFILENAMES=${INPUTFILENAMES}
    LOCALINPUTFILENAMES=""
    for INPUTFILE in $(echo ${INPUTFILENAMES} | tr ',' ' '); do
        fulldest="${INPUTFILE/*\/store\//}"
        dest=$(dirname $fulldest)
        mkdir -p ${dest}
        echo ${dest}
        XRDCP_STATUS=1
        for (( xrdcp_attempt=1; xrdcp_attempt<=MAX_RETRIES; xrdcp_attempt++ )); do
            # Redirector fallback: FNAL (1-2) -> UNL (3) -> CMS Global (4-6)
            if [ ${xrdcp_attempt} -le 2 ]; then
                XRDCP_FILE=${INPUTFILE}
            elif [ ${xrdcp_attempt} -eq 3 ]; then
                XRDCP_FILE=${INPUTFILE//cmsxrootd.fnal.gov/xrootd.unl.edu}
                echo "[xrdcp] Switching to UNL redirector"
            else
                XRDCP_FILE=${INPUTFILE//cmsxrootd.fnal.gov/cms-xrd-global.cern.ch}
                [ ${xrdcp_attempt} -eq 4 ] && echo "[xrdcp] Switching to CMS global redirector"
            fi
            echo "[xrdcp] Attempt ${xrdcp_attempt}/${MAX_RETRIES}: xrdcp ${XRDCP_FILE} ${dest}"
            xrdcp ${XRDCP_FILE} ${dest}
            XRDCP_STATUS=$?
            if [ ${XRDCP_STATUS} == 0 ]; then
                break
            fi
            echo "[xrdcp] Failed (exit ${XRDCP_STATUS}), sleeping ${RETRY_SLEEP}s"
            sleep ${RETRY_SLEEP}
        done
        if [ ${XRDCP_STATUS} != 0 ]; then
            echo "ERROR: xrdcp failed after ${MAX_RETRIES} attempts for ${INPUTFILE}"
            exit 1
        fi
        if [ -z ${LOCALINPUTFILENAMES} ]; then
            LOCALINPUTFILENAMES=${fulldest}
        else
            LOCALINPUTFILENAMES=${LOCALINPUTFILENAMES}","${fulldest}
        fi
    done
    INPUTFILENAMES=${LOCALINPUTFILENAMES}
    INPUTFILENAMES=${INPUTFILENAMES//,/ }
    echo "After XRootD copy"
    echo INPUTFILENAMES=${INPUTFILENAMES}
    ##########################################################
fi

cat gitversion.txt

# need this to find the .so files, even though they are in the same
# directory
export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:.

echo "before running: ls -lrth"
ls -lrth
ls -lrth mc/

echo -e "\n--- begin running ---\n" #                           <----- section division

EXTRAARGS="$(getjobad metis_extraargs)"
# If running under SLURM (no condor classad), use command-line extra args
if [ -z "${EXTRAARGS}" ] && [ -n "${CMDLINE_EXTRAARGS}" ]; then
    EXTRAARGS="${CMDLINE_EXTRAARGS}"
fi

# Split input files into an array
ALL_FILES=($INPUTFILENAMES)
NFILES=${#ALL_FILES[@]}

# Determine parallelism from SLURM allocation (default 1 if not set)
NPARALLEL=${SLURM_CPUS_PER_TASK:-1}
# Don't use more workers than files
if [ ${NPARALLEL} -gt ${NFILES} ]; then
    NPARALLEL=${NFILES}
fi
echo "[parallel] Total input files: ${NFILES}, workers: ${NPARALLEL}"

if [ ${NPARALLEL} -le 1 ]; then
    # Single worker: run one ./skim with retry
    for (( attempt=1; attempt<=MAX_RETRIES; attempt++ )); do
        echo "[retry] Attempt ${attempt}/${MAX_RETRIES}: ./skim $INPUTFILENAMES -n ${OUTPUTNAME} ${EXTRAARGS}"
        ./skim $INPUTFILENAMES -n ${OUTPUTNAME} ${EXTRAARGS}
        RET=$?
        if [ ${RET} == 0 ]; then
            break
        fi
        echo "[retry] ./skim failed (exit ${RET}), attempt ${attempt}/${MAX_RETRIES}, sleeping ${RETRY_SLEEP}s"
        sleep ${RETRY_SLEEP}
    done
else
    # Split files into NPARALLEL chunks and run in parallel
    PIDS=()
    PART_NAMES=()
    FILES_PER_PART=$(( (NFILES + NPARALLEL - 1) / NPARALLEL ))

    for (( p=0; p<NPARALLEL; p++ )); do
        START=$(( p * FILES_PER_PART ))
        CHUNK=("${ALL_FILES[@]:${START}:${FILES_PER_PART}}")
        if [ ${#CHUNK[@]} -eq 0 ]; then
            break
        fi
        PARTNAME="part${p}"
        PART_NAMES+=("${PARTNAME}")
        echo "[parallel] Part ${p} (${#CHUNK[@]} files): ${CHUNK[*]}"
        echo Executing ./skim "${CHUNK[@]}" -n ${OUTPUTNAME}_${PARTNAME} ${EXTRAARGS}
        ./skim "${CHUNK[@]}" -n ${OUTPUTNAME}_${PARTNAME} ${EXTRAARGS} &
        PIDS+=($!)
    done

    # Wait for all and collect failed parts
    FAILED_PARTS=()
    for (( p=0; p<${#PIDS[@]}; p++ )); do
        wait ${PIDS[$p]}
        RETCODE=$?
        echo "[parallel] Part ${p} exit code: ${RETCODE}"
        if [ ${RETCODE} != 0 ]; then
            FAILED_PARTS+=($p)
        fi
    done

    # Retry failed parts sequentially
    for (( attempt=2; attempt<=MAX_RETRIES; attempt++ )); do
        if [ ${#FAILED_PARTS[@]} -eq 0 ]; then
            break
        fi
        echo "[retry] Attempt ${attempt}/${MAX_RETRIES} for ${#FAILED_PARTS[@]} failed part(s): ${FAILED_PARTS[*]}"
        STILL_FAILED=()
        for p in "${FAILED_PARTS[@]}"; do
            START=$(( p * FILES_PER_PART ))
            CHUNK=("${ALL_FILES[@]:${START}:${FILES_PER_PART}}")
            PARTNAME="part${p}"
            echo "[retry] Re-running part ${p} (${#CHUNK[@]} files)"
            ./skim "${CHUNK[@]}" -n ${OUTPUTNAME}_${PARTNAME} ${EXTRAARGS}
            RETCODE=$?
            echo "[retry] Part ${p} attempt ${attempt} exit code: ${RETCODE}"
            if [ ${RETCODE} != 0 ]; then
                STILL_FAILED+=($p)
            fi
        done
        FAILED_PARTS=("${STILL_FAILED[@]}")
        if [ ${#FAILED_PARTS[@]} -gt 0 ] && [ ${attempt} -lt ${MAX_RETRIES} ]; then
            echo "[retry] Sleeping ${RETRY_SLEEP}s before next attempt"
            sleep ${RETRY_SLEEP}
        fi
    done

    # Final status
    RET=0
    if [ ${#FAILED_PARTS[@]} -gt 0 ]; then
        echo "[retry] Parts still failing after ${MAX_RETRIES} attempts: ${FAILED_PARTS[*]}"
        RET=1
    fi

    if [ ${RET} != 0 ] && [[ "${EXTRAARGS}" = *"ignorebadfiles"* ]]; then
        echo "[parallel] Ignoring exit codes (ignorebadfiles)"
        RET=0
    fi

    # Merge partial outputs with haddnano.py
    if [ ${RET} == 0 ]; then
        PART_ROOT_FILES=""
        for PARTNAME in "${PART_NAMES[@]}"; do
            PART_ROOT_FILES="${PART_ROOT_FILES} ${OUTPUTNAME}_${PARTNAME}.root"
        done
        echo "[parallel] Merging with haddnano.py"
        echo "Running: haddnano.py ${OUTPUTNAME}.root ${PART_ROOT_FILES}"
        haddnano.py ${OUTPUTNAME}.root ${PART_ROOT_FILES}
        MERGE_RET=$?
        if [ ${MERGE_RET} != 0 ]; then
            echo "ERROR: haddnano.py failed with exit code ${MERGE_RET}"
            rm -f ${OUTPUTNAME}.root ${PART_ROOT_FILES}
            exit 1
        fi
        # Clean up partial files
        rm -f ${PART_ROOT_FILES}
        echo "[parallel] Merge complete, cleaned up partial files"

        # Merge cutflow files from all parallel parts
        PART_NAMES_STR="${PART_NAMES[*]}"
        python3 << MERGEEOF
import csv, os, glob

def merge_csv(part_files, out):
    """Merge multiple Cutflow_TheEnd.csv files by summing numeric columns."""
    existing = [f for f in part_files if os.path.isfile(f)]
    if not existing:
        return
    if len(existing) == 1:
        os.rename(existing[0], out)
        print(f"[parallel] Renamed single cutflow CSV -> {out}")
        return
    rows = {}
    order = []
    for path in existing:
        with open(path) as f:
            reader = csv.DictReader(f)
            for row in reader:
                cut = row["cut"]
                if cut not in rows:
                    rows[cut] = {"raw_events": 0.0, "weighted_events": 0.0}
                    order.append(cut)
                rows[cut]["raw_events"] += float(row["raw_events"])
                rows[cut]["weighted_events"] += float(row["weighted_events"])
    with open(out, "w") as f:
        f.write("cut,raw_events,weighted_events\n")
        for cut in order:
            r = rows[cut]
            f.write(f"{cut},{r['raw_events']:.6f},{r['weighted_events']:.6f}\n")
    for path in existing:
        os.remove(path)
    print(f"[parallel] Merged {len(existing)} cutflow CSVs -> {out}")

def merge_cflow(part_files, out):
    """Merge multiple .cflow files by summing columns 2-5 (raw/weighted pass/fail)."""
    existing = [f for f in part_files if os.path.isfile(f)]
    if not existing:
        return
    if len(existing) == 1:
        os.rename(existing[0], out)
        print(f"[parallel] Renamed single cutflow cflow -> {out}")
        return
    rows = {}
    order = []
    for path in existing:
        with open(path) as f:
            for line in f:
                parts = line.strip().split(",")
                name = parts[0]
                nums = [float(x) for x in parts[1:5]]
                rest = parts[5:]
                if name not in rows:
                    rows[name] = [0.0]*4 + rest
                    order.append(name)
                for i in range(4):
                    rows[name][i] += nums[i]
    with open(out, "w") as f:
        for name in order:
            vals = rows[name]
            nums = [f"{int(v)}" for v in vals[:4]]
            f.write(",".join([name] + nums + vals[4:]) + "\n")
    for path in existing:
        os.remove(path)
    print(f"[parallel] Merged {len(existing)} cutflow cflows -> {out}")

part_names = "${PART_NAMES_STR}".split()
merge_csv(["${OUTPUTNAME}_" + p + "_Cutflow_TheEnd.csv" for p in part_names],
          "${OUTPUTNAME}_Cutflow_TheEnd.csv")
merge_cflow(["${OUTPUTNAME}_" + p + "_Cutflow.cflow" for p in part_names],
            "${OUTPUTNAME}_Cutflow.cflow")
MERGEEOF
    fi
fi

echo "after running: ls -lrth"
ls -lrth

if [ ${RET} != 0 ]; then
    if [[ "${EXTRAARGS}" = *"ignorebadfiles"* ]]; then
        echo "Ignoring exit code of ${RET}"
    else
        echo "Removing output file because ./skim returned exit code ${RET}"
        rm -f ${OUTPUTNAME}.root
        exit 1 # Added because otherwise condor does not know job failed?
    fi
fi

# Rigorous sweeproot which checks ALL branches for ALL events.
# If GetEntry() returns -1, then there was an I/O problem, so we will delete it
python3 -u << EOL
import sys, os
try:
    import ROOT as r
except ImportError:
    print("[RSR] ERROR: cannot import ROOT, skipping sweeproot", file=sys.stderr)
    sys.exit(1)
foundBad = False
try:
    f1 = r.TFile("${OUTPUTNAME}.root")
    t = f1.Get("Events")
    nevts = t.GetEntries()
    for i in range(0,t.GetEntries(),1):
        if t.GetEntry(i) < 0:
            foundBad = True
            print("[RSR] found bad event %i" % i)
            break
except: foundBad = True
if foundBad:
    print("[RSR] removing output file because it does not deserve to live")
    os.system("rm ${OUTPUTNAME}.root")
else: print("[RSR] passed the rigorous sweeproot")
EOL
SWEEP_RET=$?
if [ ${SWEEP_RET} != 0 ]; then
    echo "[RSR] WARNING: sweeproot failed (exit ${SWEEP_RET}), removing output as precaution"
    rm -f ${OUTPUTNAME}.root
fi

echo -e "\n--- end running ---\n" #                             <----- section division

echo "after running: ls -lrth"
ls -lrth

# Summarize Runs TTree (GenWeights) into JSON (with retry)
echo -e "\n--- begin runs summary ---\n"
RUNS_MAX_RETRIES=3
for (( runs_attempt=1; runs_attempt<=RUNS_MAX_RETRIES; runs_attempt++ )); do
    echo "[runs] attempt ${runs_attempt}/${RUNS_MAX_RETRIES}"
    rm -f runs_summary.json runs_summary.tmp.json
    python3 -u << RUNSEOF
import sys
try:
    import ROOT as r
except ImportError:
    print("[runs] ERROR: cannot import ROOT, skipping runs_summary", file=sys.stderr)
    sys.exit(1)
import json, os

fname = "${OUTPUTNAME}.root"
out = {}

if os.path.isfile(fname):
    f = r.TFile.Open(fname)

    # Get total events from Events tree
    events_tree = f.Get("Events")
    if events_tree:
        out["eventCount"] = int(events_tree.GetEntries())

    # MC: summarize GenWeights from Runs TTree
    t = f.Get("Runs")
    if t and t.GetBranch("genEventCount"):
        scalars = {"genEventCount": 0, "genEventSumw": 0.0, "genEventSumw2": 0.0}
        arrays = {}

        for i in range(t.GetEntries()):
            t.GetEntry(i)
            for k in scalars:
                scalars[k] += getattr(t, k)
            if i == 0:
                for bname in ["LHEScaleSumw", "LHEPdfSumw", "PSSumw"]:
                    br = t.GetBranch(bname)
                    if br:
                        n = getattr(t, "n" + bname)
                        arrays[bname] = [0.0] * n
            for bname, sums in arrays.items():
                vals = getattr(t, bname)
                for j in range(len(sums)):
                    sums[j] += vals[j]

        out.update(scalars)
        out.update(arrays)

    f.Close()
else:
    print("[runs] WARNING: Output file not found, skipping runs summary")

if out:
    # Ensure all values are JSON-serializable (convert ROOT types)
    for k, v in out.items():
        if isinstance(v, list):
            out[k] = [float(x) for x in v]
        elif isinstance(v, float) or hasattr(v, '__float__'):
            out[k] = float(v)
        elif isinstance(v, int) or hasattr(v, '__int__'):
            out[k] = int(v)
    try:
        with open("runs_summary.tmp.json", "w") as jf:
            json.dump(out, jf, indent=2)
        os.rename("runs_summary.tmp.json", "runs_summary.json")
        print("[runs] Wrote runs_summary.json")
    except Exception as e:
        print("[runs] ERROR: failed to write JSON:", e, file=sys.stderr)
        if os.path.exists("runs_summary.tmp.json"):
            os.remove("runs_summary.tmp.json")
    if "genEventCount" in out:
        print("[runs] genEventCount:", out["genEventCount"])
        print("[runs] genEventSumw:", out["genEventSumw"])
    print("[runs] eventCount:", out.get("eventCount"))
else:
    print("[runs] No data to write")
RUNSEOF
    RUNS_RET=$?
    if [ ${RUNS_RET} != 0 ]; then
        echo "[runs] WARNING: runs_summary failed (exit ${RUNS_RET})"
    fi
    # Validate runs_summary.json if it exists
    if [ -f "runs_summary.json" ]; then
        if [ ! -s "runs_summary.json" ]; then
            echo "[runs] WARNING: runs_summary.json is empty (0 bytes), removing"
            rm -f runs_summary.json
        else
            python3 -c "import json; json.load(open('runs_summary.json'))" 2>/dev/null
            if [ $? != 0 ]; then
                echo "[runs] WARNING: runs_summary.json is invalid JSON, removing"
                rm -f runs_summary.json
            fi
        fi
    fi
    # If valid JSON exists, we're done
    if [ -f "runs_summary.json" ]; then
        echo "[runs] runs_summary.json OK (attempt ${runs_attempt})"
        break
    fi
    # Retry unless last attempt
    if [ ${runs_attempt} -lt ${RUNS_MAX_RETRIES} ]; then
        echo "[runs] Retrying runs_summary in 5s..."
        sleep 5
    else
        echo "[runs] WARNING: runs_summary failed after ${RUNS_MAX_RETRIES} attempts, no runs_summary.json will be produced"
    fi
done
echo -e "\n--- end runs summary ---\n"

if [[ $(hostname) == *"ufhpc"* ]]; then
    echo -e "\n--- begin copying output (HiPerGator shared filesystem) ---\n"
    COPY_DEST_DIR="${OUTPUTDIR}"
    COPY_DEST="${COPY_DEST_DIR}/${OUTPUTNAME}_${IFILE}.root"
    echo "Running: mkdir -p ${COPY_DEST_DIR}"
    mkdir -p ${COPY_DEST_DIR}
    echo "Running: cp ${OUTPUTNAME}.root ${COPY_DEST}"
    cp ${OUTPUTNAME}.root ${COPY_DEST}
    COPY_STATUS=$?
    if [[ $COPY_STATUS == 0 ]]; then
        echo "Copy success!"
    else
        echo "ERROR: Copy failed with exit code $COPY_STATUS"
        exit 1
    fi
    # Copy cutflow files if they exist
    if [ -f "cutflow.txt" ]; then
        cp cutflow.txt ${COPY_DEST_DIR}/cutflow_${IFILE}.txt
    fi
    if [ -f "${OUTPUTNAME}_Cutflow.cflow" ]; then
        cp ${OUTPUTNAME}_Cutflow.cflow ${COPY_DEST_DIR}/cutflow_${IFILE}.cflow
    fi
    if [ -f "${OUTPUTNAME}_Cutflow_TheEnd.csv" ]; then
        cp ${OUTPUTNAME}_Cutflow_TheEnd.csv ${COPY_DEST_DIR}/cutflow_${IFILE}.csv
    fi
    if [ -f "runs_summary.json" ]; then
        cp runs_summary.json ${COPY_DEST_DIR}/runs_summary_${IFILE}.json
    fi
elif [[ $(hostname) == *"uaf-10"* ]]; then
    echo -e "\n--- begin copying output ---\n" #                    <----- section division
    echo "Sending output file output/${OUTPUTNAME}.root"
    OUTPUTDIRPATHNEW=$(echo ${OUTPUTDIR} | sed 's/^.*\(\/store.*\).*$/\1/')
    COPY_SRC="output/${OUTPUTNAME}.root"
    COPY_DEST_DIR="/ceph/cms/${OUTPUTDIRPATHNEW}/"
    COPY_DEST="${COPY_DEST_DIR}/${OUTPUTNAME}_${IFILE}.root"
    echo "Running: mkdir -p ${COPY_DEST_DIR}"
    mkdir -p ${COPY_DEST_DIR}
    echo "Running: cp ${COPY_SRC} ${COPY_DEST}"
    cp ${COPY_SRC} ${COPY_DEST}
    COPY_STATUS=$?
    if [[ $COPY_STATUS == 0 ]]; then
        echo "Copy success!"
    fi
else
    echo -e "\n--- begin copying output ---\n" #                    <----- section division
    # copy output.root file
    echo "Sending output file output/${OUTPUTNAME}.root"
    OUTPUTDIRPATHNEW=$(echo ${OUTPUTDIR} | sed 's/^.*\(\/store.*\).*$/\1/')
    COPY_SRC="file://`pwd`/${OUTPUTNAME}.root"
    COPY_DEST="davs://redirector.t2.ucsd.edu:1095//${OUTPUTDIRPATHNEW}/${OUTPUTNAME}_${IFILE}.root"

    echo "Running: env -i X509_USER_PROXY=${X509_USER_PROXY} gfal-copy -p -f -t 4200 --verbose --checksum ADLER32 ${COPY_SRC} ${COPY_DEST}"
    env -i X509_USER_PROXY=${X509_USER_PROXY} gfal-copy -p -f -t 4200 --verbose --checksum ADLER32 ${COPY_SRC} ${COPY_DEST}
    COPY_STATUS=$?

    if [[ $COPY_STATUS != 0 ]]; then
        echo "Removing output file because gfal-copy crashed with code $COPY_STATUS"
        env -i X509_USER_PROXY=${X509_USER_PROXY} gfal-rm --verbose ${COPY_DEST}
        REMOVE_STATUS=$?
        if [[ $REMOVE_STATUS != 0 ]]; then
            echo "Uhh, gfal-copy crashed and then the gfal-rm also crashed with code $REMOVE_STATUS"
        fi
        exit 1
    fi

    # copy cuflow.txt file if it exists
    echo "Sending output file output/cutflow.txt if it exists"
    COPY_SRC_CUTFLOW="file://`pwd`/cutflow.txt"
    COPY_DEST_CUTFLOW="davs://redirector.t2.ucsd.edu:1095//${OUTPUTDIRPATHNEW}/cutflow_${IFILE}.txt"
    if [ -f "$(pwd)/cutflow.txt" ]; then
        echo "Running: env -i X509_USER_PROXY=${X509_USER_PROXY} gfal-copy -p -f -t 4200 --verbose --checksum ADLER32 ${COPY_SRC_CUTFLOW} ${COPY_DEST_CUTFLOW}"
        env -i X509_USER_PROXY=${X509_USER_PROXY} gfal-copy -p -f -t 4200 --verbose --checksum ADLER32 ${COPY_SRC_CUTFLOW} ${COPY_DEST_CUTFLOW}
    else
        echo "Warning: gfal-ls command failed or file  '$COPY_SRC_CUTFLOW' does not exist:"
    fi

    echo "Sending output file ${OUTPUTNAME}_Cutflow.cflow if it exists"
    COPY_SRC_CUTFLOW="file://`pwd`/${OUTPUTNAME}_Cutflow.cflow"
    COPY_DEST_CUTFLOW="davs://redirector.t2.ucsd.edu:1095//${OUTPUTDIRPATHNEW}/cutflow_${IFILE}.cflow"
    if [ -f "$(pwd)/${OUTPUTNAME}_Cutflow.cflow" ]; then
        echo "Running: env -i X509_USER_PROXY=${X509_USER_PROXY} gfal-copy -p -f -t 4200 --verbose --checksum ADLER32 ${COPY_SRC_CUTFLOW} ${COPY_DEST_CUTFLOW}"
        env -i X509_USER_PROXY=${X509_USER_PROXY} gfal-copy -p -f -t 4200 --verbose --checksum ADLER32 ${COPY_SRC_CUTFLOW} ${COPY_DEST_CUTFLOW}
    else
        echo "Warning: file '${OUTPUTNAME}_Cutflow.cflow' does not exist"
    fi

    echo "Sending output file ${OUTPUTNAME}_Cutflow_TheEnd.csv if it exists"
    COPY_SRC_CUTFLOW="file://`pwd`/${OUTPUTNAME}_Cutflow_TheEnd.csv"
    COPY_DEST_CUTFLOW="davs://redirector.t2.ucsd.edu:1095//${OUTPUTDIRPATHNEW}/cutflow_${IFILE}.csv"
    if [ -f "$(pwd)/${OUTPUTNAME}_Cutflow_TheEnd.csv" ]; then
        echo "Running: env -i X509_USER_PROXY=${X509_USER_PROXY} gfal-copy -p -f -t 4200 --verbose --checksum ADLER32 ${COPY_SRC_CUTFLOW} ${COPY_DEST_CUTFLOW}"
        env -i X509_USER_PROXY=${X509_USER_PROXY} gfal-copy -p -f -t 4200 --verbose --checksum ADLER32 ${COPY_SRC_CUTFLOW} ${COPY_DEST_CUTFLOW}
    else
        echo "Warning: file '${OUTPUTNAME}_Cutflow_TheEnd.csv' does not exist"
    fi

    echo "Sending output file runs_summary.json if it exists"
    COPY_SRC_RUNS="file://$(pwd)/runs_summary.json"
    COPY_DEST_RUNS="davs://redirector.t2.ucsd.edu:1095//${OUTPUTDIRPATHNEW}/runs_summary_${IFILE}.json"
    if [ -f "$(pwd)/runs_summary.json" ]; then
        env -i X509_USER_PROXY=${X509_USER_PROXY} gfal-copy -p -f -t 4200 --verbose --checksum ADLER32 ${COPY_SRC_RUNS} ${COPY_DEST_RUNS}
    fi
fi
