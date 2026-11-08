# Prints the mean R/G/B/A of every 256x256 k_2_10_10_10 mask dump (1A4F0000) in time order.
# usage: python -I mask_series.py <dumps dir>
import os, struct, sys

d = sys.argv[1]
for name in sorted(f for f in os.listdir(d) if '1A4F0000' in f and f.endswith('.bin')):
    data = open(os.path.join(d, name), 'rb').read()
    n = len(data) // 4
    sr = sg = sb = sa = 0
    for (v,) in struct.iter_unpack('>I', data):
        sr += v & 0x3FF
        sg += (v >> 10) & 0x3FF
        sb += (v >> 20) & 0x3FF
        sa += v >> 30
    print(f'{name}: R {sr / n:7.1f} G {sg / n:7.1f} B {sb / n:7.1f} A {sa / n:4.2f}')
