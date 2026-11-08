"""Extract the game partition of an Xbox 360 disc image (XDVDFS) to a folder.

usage: python -I xiso_x.py <disc.iso | svod package> <out_dir>
Disc image: finds the partition itself: plain XISO (0), XGD3 (0x2080000), XGD2 (0xFD90000),
XGD1 (0x18300000).
SVOD package (Games on Demand 00007000 or a hard-drive install 00004000): pass the header
file, its .data folder, or the folder holding both. The DataNNNN files are the disc with hash
blocks woven in, which are skipped here.
"""
import glob, os, struct, sys

iso, out = sys.argv[1:3]
C = 1 << 22
MAGIC = b'MICROSOFT*XBOX*MEDIA'


class Svod:
    """Read-only view of SVOD DataNNNN files as one continuous stream, hash blocks removed.

    Each data file (up to 0xA290000 bytes) is a 0x1000 level-1 hash block followed by groups
    of [0x1000 level-0 hash block][0x198 blocks of 0x800 data].
    """
    GROUP_DATA = 0x198 * 0x800
    GROUP = 0x1000 + GROUP_DATA
    PER_FILE = (0xA290000 - 0x1000) // GROUP * GROUP_DATA

    def __init__(self, data_dir):
        self.paths = sorted(glob.glob(os.path.join(data_dir, 'Data[0-9][0-9][0-9][0-9]')))
        if not self.paths:
            sys.exit('no DataNNNN files in ' + data_dir)
        for i, p in enumerate(self.paths):
            if os.path.basename(p) != 'Data%04d' % i:
                sys.exit('data files not contiguous at ' + p)
        last = os.path.getsize(self.paths[-1]) - 0x1000
        groups = -(-last // self.GROUP)
        self.size = (len(self.paths) - 1) * self.PER_FILE + last - groups * 0x1000
        self.handles = {}
        self.pos = 0

    def seek(self, o):
        self.pos = o

    def read(self, n):
        parts = []
        while n > 0 and 0 <= self.pos < self.size:
            fi, r = divmod(self.pos, self.PER_FILE)
            g, within = divmod(r, self.GROUP_DATA)
            k = min(n, self.GROUP_DATA - within)
            h = self.handles.get(fi)
            if h is None:
                h = self.handles[fi] = open(self.paths[fi], 'rb')
            h.seek(0x1000 + g * self.GROUP + 0x1000 + within)
            b = h.read(k)
            if not b:
                break
            parts.append(b)
            self.pos += len(b)
            n -= len(b)
        return b''.join(parts)


def svod_data_dir(p):
    if os.path.isdir(p) and glob.glob(os.path.join(p, 'Data0000')):
        return p
    if os.path.isfile(p) and os.path.isdir(p + '.data'):
        return p + '.data'
    if os.path.isdir(p):
        hits = glob.glob(os.path.join(p, '*.data'))
        if len(hits) == 1:
            return hits[0]
    return None


ddir = svod_data_dir(iso)
f = Svod(ddir) if ddir else open(iso, 'rb')


def rd(o, n):
    f.seek(o)
    return f.read(n)


if ddir:
    # The volume descriptor is sector 32 of the partition; where that lands in the stream
    # depends on the SVOD layout (EGDF, XSF, single file), so look for it.
    head = rd(0, 0x40000)
    at = next((o for o in range(0, len(head), 0x800) if head[o:o + 20] == MAGIC), None)
    if at is None:
        sys.exit('no XDVDFS volume descriptor found in ' + ddir)
    v = head[at:at + 2048]
    # The stream starts with a copy of the volume descriptor; disc sectors follow from the
    # package's data block offset (header 0x395, 3 bytes LE, 0x1000 units), so sector s sits
    # at s * 0x800 - (offset - 1) * 0x1000. Checked on a Games on Demand package (offset 0x1C)
    # and a hard-drive install of an XGD1 disc (0x5D13). Without the header, try the
    # usual bases. Either way, keep only a base where the root directory parses.
    root0 = struct.unpack('<I', v[20:24])[0]
    bases = []
    hdr = ddir[:-5] if ddir.endswith('.data') else None
    if hdr and os.path.isfile(hdr):
        with open(hdr, 'rb') as hf:
            h = hf.read(0x398)
        if h[:4] in (b'CON ', b'LIVE', b'PIRS'):
            off = int.from_bytes(h[0x395:0x398], 'little')
            bases.append(-(off - 1) * 0x1000)
            print('svod: data block offset', hex(off))
    bases += [at - 32 * 2048 - 0xB000, at - 32 * 2048]

    def parses(base):
        d = rd(base + root0 * 2048, 64)
        if len(d) < 14:
            return False
        n = d[13]
        return 0 < n < 64 and all(32 <= c < 127 for c in d[14:14 + n])

    for B in bases:
        if parses(B):
            break
    else:
        sys.exit('svod: root directory not found at any known base')
    print('svod: %d data files, %d bytes of disc data' % (len(f.paths), f.size))
else:
    for B in (0, 0x2080000, 0xFD90000, 0x18300000):
        v = rd(B + 32 * 2048, 2048)
        if v[:20] == MAGIC:
            break
    else:
        sys.exit('no XDVDFS volume descriptor found')
print('partition at', hex(B))
root, rsz = struct.unpack('<II', v[20:28])
nf = nb = nd = 0


def walk(sec, size, dir):
    global nf, nb, nd
    d = rd(B + sec * 2048, size)
    seen = set()
    st = [0]
    while st:
        off = st.pop()
        if off in seen or off + 14 > len(d):
            continue
        seen.add(off)
        l, r, s, z, a, n = struct.unpack('<HHIIBB', d[off:off + 14])
        if l == 0xFFFF:
            continue
        name = d[off + 14:off + 14 + n].decode('latin1')
        if not name or name in ('.', '..') or any(c in name for c in '/\\:'):
            sys.exit('bad name %r' % name)
        if l:
            st.append(l * 4)
        if r:
            st.append(r * 4)
        p = os.path.join(dir, name)
        if a & 0x10:
            os.makedirs(p, exist_ok=True)
            nd += 1
            if z:
                walk(s, z, p)
        else:
            with open(p, 'xb') as o:
                f.seek(B + s * 2048)
                left = z
                while left:
                    b = f.read(min(C, left))
                    if not b:
                        sys.exit('short read ' + p)
                    o.write(b)
                    left -= len(b)
            nf += 1
            nb += z


os.makedirs(out, exist_ok=True)
walk(root, rsz, out)
got = sum(os.path.getsize(os.path.join(r, x)) for r, _, fs in os.walk(out) for x in fs)
cnt = sum(len(fs) for r, _, fs in os.walk(out))
print('files', nf, 'dirs', nd, 'bytes', nb, 'on disk', cnt, got, 'OK' if (cnt, got) == (nf, nb) else 'MISMATCH')
print(sorted(os.listdir(out)))
