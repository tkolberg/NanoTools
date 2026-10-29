from metis.Sample import DirectorySample, DBSSample
from vbsvvh_data import nanoaodv15_run3_data, nanoaodv15_run2_data, nanoaodv15_run3_data_2025, nanoaodv15_run3_data_2026, nanoaodv15_run3_data_2026_jetmet
from vbsvvh_mc import nanoaodv15_run2_bkg, nanoaodv15_run2_sig, nanoaodv15_run3_bkg, nanoaodv15_run3_sig
from vbsvvh_mc import nanoaodv15_run2_bkg_dy_htbinned, nanoaodv15_run2_bkg_dy_jetbinned
from vbsvvh_mc import nanoaodv15_run2_bkg_zz4l, nanoaodv15_run3_bkg_ggzz4l
from vbsvvh_mc import nanoaodv15_run3_bkg_zh4l
from vbsvvh_hh import nanoaodv15_run3_bkg_hh, nanoaodv13_run3_bkg_hh_bbtautau
import vbsvvh_v14
from vbsvvh_vjets import nanoaodv15_run2_bkg_znunu_ht, nanoaodv15_run3_bkg_vjets_ht
from vbsvvh_ellis import nanoaodv15_run2_bkg_zz4l_extra, nanoaodv15_run2_bkg_vg2l, nanoaodv15_run3_bkg_vg2l
from vbsvvh_parking import nanoaodv15_run3_data_parking


# Temporary test group: just the new QCD-4Jets HT-100to200 Run3 Summer24 sample
nanoaodv15_run3_bkg_qcd4jets_test = [
    DBSSample(dataset="/QCD-4Jets_Bin-HT-100to200_TuneCP5_13p6TeV_madgraphMLM-pythia8/RunIII2024Summer24NanoAODv15-150X_mcRun3_2024_realistic_v2-v2/NANOAODSIM"),
]


# New low-C2V Run3 signal scan points (C2V=0.25 and C2V=0.75, both C3=1.0),
# 4 processes each = 8 samples, filtered out of the full run3_sig grid. Isolated
# group so a dedicated version skims ONLY these 8; fold into v30 via symlink
# afterward (the v32/run3_data_2025 pattern).
nanoaodv15_run3_sig_lowc2v = [
    s for s in nanoaodv15_run3_sig
    if "c2v0p25" in s.get_datasetname() or "c2v0p75" in s.get_datasetname()
]


# ---------------------------------------------------------------------------
# Sample registry: maps CLI-friendly names -> (sample_list, metadata)
# ---------------------------------------------------------------------------
SAMPLE_REGISTRY = {
    "run2_data": {
        "samples": nanoaodv15_run2_data,
        "metadata": {"run": "Run2", "type": "Data", "nano": "v15"},
    },
    "run2_bkg": {
        "samples": nanoaodv15_run2_bkg,
        "metadata": {"run": "Run2", "type": "Bkg", "nano": "v15"},
    },
    "run2_sig": {
        "samples": nanoaodv15_run2_sig,
        "metadata": {"run": "Run2", "type": "Sig", "nano": "v15"},
    },
    "run3_data": {
        "samples": nanoaodv15_run3_data,
        "metadata": {"run": "Run3", "type": "Data", "nano": "v15"},
    },
    "run3_data_2025": {
        "samples": nanoaodv15_run3_data_2025,
        "metadata": {"run": "Run3", "type": "Data", "nano": "v15"},
    },
    # 2026 PromptReco (eras A-D), lepton PDs only. Needs year-2026 support in
    # NanoCORE and the EGamma4/5 + Muon2/3 entries in submit.py LEPTON_PDS.
    "run3_data_2026": {
        "samples": nanoaodv15_run3_data_2026,
        "metadata": {"run": "Run3", "type": "Data", "nano": "v15"},
    },
    # 2026 PromptReco JetMET, eras A, B, D (see vbsvvh_data.py).
    "run3_data_2026_jetmet": {
        "samples": nanoaodv15_run3_data_2026_jetmet,
        "metadata": {"run": "Run3", "type": "Data", "nano": "v15"},
    },
    "run3_bkg": {
        "samples": nanoaodv15_run3_bkg,
        "metadata": {"run": "Run3", "type": "Bkg", "nano": "v15"},
    },
    "run3_sig": {
        "samples": nanoaodv15_run3_sig,
        "metadata": {"run": "Run3", "type": "Sig", "nano": "v15"},
    },
    "run3_sig_lowc2v": {
        "samples": nanoaodv15_run3_sig_lowc2v,
        "metadata": {"run": "Run3", "type": "Sig", "nano": "v15"},
    },
    "run3_bkg_qcd4jets_test": {
        "samples": nanoaodv15_run3_bkg_qcd4jets_test,
        "metadata": {"run": "Run3", "type": "Bkg", "nano": "v15"},
    },
    # High-stat DY alternatives to the inclusive M-50 in run2_bkg (multi-(b)jet
    # phase space). ALTERNATIVES — stitch / pick one scheme; do NOT submit
    # alongside run2_bkg's inclusive DY without handling double-counting.
    "run2_bkg_dy_ht": {
        "samples": nanoaodv15_run2_bkg_dy_htbinned,
        "metadata": {"run": "Run2", "type": "Bkg", "nano": "v15"},
    },
    "run2_bkg_dy_jet": {
        "samples": nanoaodv15_run2_bkg_dy_jetbinned,
        "metadata": {"run": "Run2", "type": "Bkg", "nano": "v15"},
    },
    # Extra ZZ->4L samples requested for the 4Lep channel study. Isolated groups
    # so a dedicated version skims only these; fold into v30 by symlink after.
    # run2_bkg_zz4l OVERLAPS ZZTo4L_M-1toInf in run2_bkg — pick one downstream.
    "run2_bkg_zz4l": {
        "samples": nanoaodv15_run2_bkg_zz4l,
        "metadata": {"run": "Run2", "type": "Bkg", "nano": "v15"},
    },
    "run3_bkg_ggzz4l": {
        "samples": nanoaodv15_run3_bkg_ggzz4l,
        "metadata": {"run": "Run3", "type": "Bkg", "nano": "v15"},
    },
    # ZH production with H->ZZ->4L. Complementary to v30's ggH GluGluH-Hto2Zto4L
    # (different production mode) -- no double-counting with it.
    "run3_bkg_zh4l": {
        "samples": nanoaodv15_run3_bkg_zh4l,
        "metadata": {"run": "Run3", "type": "Bkg", "nano": "v15"},
    },
    # Di-Higgs. Summer24 NanoAODv15 -- same campaign as v30's Run3 Bkg, so these
    # fold straight into Run3_Bkg_v15_v30_<channel>. NO overlap with anything
    # already in v30: HH has never been in this production.
    "run3_bkg_hh": {
        "samples": nanoaodv15_run3_bkg_hh,
        "metadata": {"run": "Run3", "type": "Bkg", "nano": "v15"},
    },
    # ggHH->bbtautau, only exists up to NanoAODv13 (Summer22). Separate group so
    # the nano version in the tag stays honest; needs --tag-subst v13=v15 when
    # linking into v30. Different year from run3_bkg_hh -- not stackable with it.
    "run3_bkg_hh_bbtautau": {
        "samples": nanoaodv13_run3_bkg_hh_bbtautau,
        "metadata": {"run": "Run3", "type": "Bkg", "nano": "v13"},
    },
    # V+jets HT-binned (M. Mazza request, 2026-09-15). See vbsvvh_vjets.py for
    # the HT-bin-edge and double-counting caveats -- in particular the 2024
    # W->lnu set OVERLAPS the pT- and jet-binned W+jets already in run3_bkg.
    "run2_bkg_znunu_ht": {
        "samples": nanoaodv15_run2_bkg_znunu_ht,
        "metadata": {"run": "Run2", "type": "Bkg", "nano": "v15"},
    },
    "run3_bkg_vjets_ht": {
        "samples": nanoaodv15_run3_bkg_vjets_ht,
        "metadata": {"run": "Run3", "type": "Bkg", "nano": "v15"},
    },
    # S. Ellis request (mc_sample_request.txt). Channel-specific by design:
    # zz4l_extra -> 4Lep, vg2l -> 2Lep1FJ. See vbsvvh_ellis.py.
    "run2_bkg_zz4l_extra": {
        "samples": nanoaodv15_run2_bkg_zz4l_extra,
        "metadata": {"run": "Run2", "type": "Bkg", "nano": "v15"},
    },
    "run2_bkg_vg2l": {
        "samples": nanoaodv15_run2_bkg_vg2l,
        "metadata": {"run": "Run2", "type": "Bkg", "nano": "v15"},
    },
    "run3_bkg_vg2l": {
        "samples": nanoaodv15_run3_bkg_vg2l,
        "metadata": {"run": "Run3", "type": "Bkg", "nano": "v15"},
    },
    # B-parking HH data 2023-2026, for the 0Lep channels.
    # ** Contains overlapping reprocessings of 7 run ranges -- see the warning
    # ** at the top of vbsvvh_parking.py before combining these downstream.
    "run3_data_parking": {
        "samples": nanoaodv15_run3_data_parking,
        "metadata": {"run": "Run3", "type": "Data", "nano": "v15"},
    },
}

# ------------------------------------------------------------------
# LPC PFNano NanoAODv14 (nanoindex_v14_HVV_private.json).
# Registered programmatically -- 12 groups (4 eras x Bkg/Data/Sig). The index is
# large (38 MB), so vbsvvh_v14 parses it lazily on first access.
# Needs the year/JetId fixes in 458911d; see vbsvvh_v14.py for why.
# ------------------------------------------------------------------
for _name, (_samples, _metadata) in vbsvvh_v14.get_groups().items():
    SAMPLE_REGISTRY[_name] = {"samples": _samples, "metadata": _metadata}


def get_samples(name):
    """Return (sample_list, metadata_dict) for a registry key."""
    entry = SAMPLE_REGISTRY[name]
    return entry["samples"], entry["metadata"]


def list_groups():
    """Print a table of all available sample groups."""
    print(f"{'Group':<15} {'Run':<6} {'Type':<6} {'Nano':<5} {'# Samples'}")
    print("-" * 50)
    for name, entry in SAMPLE_REGISTRY.items():
        m = entry["metadata"]
        n = len(entry["samples"])
        print(f"{name:<15} {m['run']:<6} {m['type']:<6} {m['nano']:<5} {n}")


# Backward compat: bare import still works (empty by default)
samples_to_submit = []
