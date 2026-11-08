# Untiles a Xenos 2D-tiled 32bpp resolve dump (k_24_8 depth) and writes a grayscale PNG plus stats.
# usage: python -I untile_depth.py <dump.bin> [width] [height] [endian 0-3] [rgb10a2|k8]
import struct, sys, zlib

def tiled_offset(x, y, pitch, bpp_log2=2):
    # Xenos Tiled2D (xenia texture_address), returns a byte offset.
    macro = ((y >> 5) * (pitch >> 5)) << (bpp_log2 + 7)
    micro = ((y & 6) << 2) << bpp_log2
    row = macro + ((micro & ~0xF) << 1) + (micro & 0xF) + ((y & 8) << (3 + bpp_log2)) + ((y & 1) << 4)
    macro = (x >> 5) << (bpp_log2 + 7)
    micro = (x & 7) << bpp_log2
    off = row + macro + ((micro & ~0xF) << 1) + (micro & 0xF)
    return (((off & ~0x1FF) << 3) + ((off & 0x1C0) << 2) + (off & 0x3F) + ((y & 16) << 7) +
            (((((y & 8) >> 2) + (x >> 3)) & 3) << 6))

def word(data, o, endian):
    b = data[o:o + 4]
    if endian == 0:   # none: guest big-endian layout as stored
        return struct.unpack('>I', b)[0]
    if endian == 1:   # 8in16
        return struct.unpack('>I', bytes([b[1], b[0], b[3], b[2]]))[0]
    if endian == 2:   # 8in32
        return struct.unpack('<I', b)[0]
    return struct.unpack('>I', bytes([b[2], b[3], b[0], b[1]]))[0]  # 16in32

def png(path, w, h, rows):
    raw = b''.join(b'\x00' + bytes(r) for r in rows)
    def chunk(t, d):
        c = struct.pack('>I', len(d)) + t + d
        return c + struct.pack('>I', zlib.crc32(t + d) & 0xFFFFFFFF)
    with open(path, 'wb') as f:
        f.write(b'\x89PNG\r\n\x1a\n' + chunk(b'IHDR', struct.pack('>IIBBBBB', w, h, 8, 0, 0, 0, 0)) +
                chunk(b'IDAT', zlib.compress(raw, 6)) + chunk(b'IEND', b''))

def png_rgb(path, w, h, rows):
    raw = b''.join(b'\x00' + bytes(r) for r in rows)
    def chunk(t, d):
        c = struct.pack('>I', len(d)) + t + d
        return c + struct.pack('>I', zlib.crc32(t + d) & 0xFFFFFFFF)
    with open(path, 'wb') as f:
        f.write(b'\x89PNG\r\n\x1a\n' + chunk(b'IHDR', struct.pack('>IIBBBBB', w, h, 8, 2, 0, 0, 0)) +
                chunk(b'IDAT', zlib.compress(raw, 6)) + chunk(b'IEND', b''))

def rgb10a2(path, w, h, endian):
    # k_2_10_10_10: R bits 0-9, G 10-19, B 20-29, A 30-31. Writes <name>.png (RGB) and <name>_a.png.
    data = open(path, 'rb').read()
    rows, arows, hist = [], [], {}
    for y in range(h):
        row, arow = [], []
        for x in range(w):
            v = word(data, tiled_offset(x, y, w), endian)
            r, g, b, a = v & 0x3FF, (v >> 10) & 0x3FF, (v >> 20) & 0x3FF, v >> 30
            row += [r >> 2, g >> 2, b >> 2]
            arow.append(a * 85)
            hist[(r >> 6, g >> 6, b >> 6, a)] = hist.get((r >> 6, g >> 6, b >> 6, a), 0) + 1
        rows.append(row)
        arows.append(arow)
    top = sorted(hist.items(), key=lambda kv: -kv[1])[:8]
    print(f'{path}: top (r,g,b,a in 16ths/alpha 0-3): ' +
          ', '.join(f'{k}:{v * 100 / (w * h):.1f}%' for k, v in top))
    png_rgb(path[:-4] + '.png', w, h, rows)
    png(path[:-4] + '_a.png', w, h, arows)

def k8(path, w, h):
    # k_8 (1 byte per texel): writes <name>.png as grayscale. Pitch is aligned to 32 texels.
    data = open(path, 'rb').read()
    pitch = (w + 31) & ~31
    rows = []
    for y in range(h):
        rows.append([data[tiled_offset(x, y, pitch, 0)] for x in range(w)])
    flat = [v for r in rows for v in r]
    print(f'{path}: min {min(flat)} max {max(flat)} mean {sum(flat) / len(flat):.1f} '
          f'255s {sum(1 for v in flat if v == 255) * 100 / len(flat):.1f}%')
    png(path[:-4] + '.png', w, h, rows)

def k88(path, w, h):
    # k_8_8 (2 bytes per texel, guest big-endian): writes <name>_0.png and <name>_1.png per byte.
    data = open(path, 'rb').read()
    pitch = (w + 31) & ~31
    rows0, rows1 = [], []
    for y in range(h):
        r0, r1 = [], []
        for x in range(w):
            o = tiled_offset(x, y, pitch, 1)
            r0.append(data[o])
            r1.append(data[o + 1])
        rows0.append(r0)
        rows1.append(r1)
    for name, rows in (('_0', rows0), ('_1', rows1)):
        flat = [v for r in rows for v in r]
        print(f'{path}{name}: min {min(flat)} max {max(flat)} mean {sum(flat) / len(flat):.1f}')
        png(path[:-4] + name + '.png', w, h, rows)

def main():
    path = sys.argv[1]
    if len(sys.argv) > 5 and sys.argv[5] == 'k88':
        k88(path, int(sys.argv[2]), int(sys.argv[3]))
        return
    if len(sys.argv) > 5 and sys.argv[5] == 'k8':
        k8(path, int(sys.argv[2]), int(sys.argv[3]))
        return
    if len(sys.argv) > 5 and sys.argv[5] == 'rgb10a2':
        rgb10a2(path, int(sys.argv[2]), int(sys.argv[3]), int(sys.argv[4]))
        return
    w = int(sys.argv[2]) if len(sys.argv) > 2 else 1024
    h = int(sys.argv[3]) if len(sys.argv) > 3 else 1024
    endian = int(sys.argv[4]) if len(sys.argv) > 4 else 2
    data = open(path, 'rb').read()
    depths = []
    for y in range(h):
        depths.append([word(data, tiled_offset(x, y, w), endian) >> 8 for x in range(w)])
    flat = [d for r in depths for d in r]
    lo, hi = min(flat), max(flat)
    full = sum(1 for d in flat if d == 0xFFFFFF)
    zero = sum(1 for d in flat if d == 0)
    print(f'{path}: min {lo:06X} max {hi:06X} cleared(FFFFFF) {full * 100 / len(flat):.1f}% zero {zero * 100 / len(flat):.1f}%')
    # Stretch only the drawn (non-cleared) range over 0..254; cleared texels stay white.
    drawn = [d for d in flat if d != 0xFFFFFF] or [0]
    lo2, hi2 = min(drawn), max(drawn)
    rng = max(1, hi2 - lo2)
    print(f'  drawn range {lo2:06X}..{hi2:06X}')
    rows = [[255 if d == 0xFFFFFF else (d - lo2) * 254 // rng for d in r] for r in depths]
    png(path[:-4] + '.png', w, h, rows)

main()
