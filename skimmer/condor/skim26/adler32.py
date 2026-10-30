"""adler32 of a file as 8 lowercase hex digits (xrdadler32 is not on HPG nodes)."""
import sys, zlib
a = 1
with open(sys.argv[1], "rb") as fh:
    for b in iter(lambda: fh.read(1 << 24), b""):
        a = zlib.adler32(b, a)
print(f"{a & 0xffffffff:08x}")
