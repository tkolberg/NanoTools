"""Read every Events branch of a NanoAOD file in 10k-entry chunks with uproot.
Prints entries and the entry ranges whose baskets fail to decompress or decode."""
import sys, uproot
f = sys.argv[1]
t = uproot.open(f)["Events"]
n = t.num_entries; step = 10000; bad = []
for start in range(0, n, step):
    stop = min(n, start + step)
    try:
        for _ in t.iterate(step_size=stop - start, entry_start=start, entry_stop=stop, library="np"):
            pass
    except Exception as e:
        bad.append((start, stop, type(e).__name__))
print(f"[read] {f.split('/')[-1]} entries {n} bad_chunks {len(bad)} bad_entries {sum(b - a for a, b, _ in bad)} first {bad[:2]}", flush=True)
