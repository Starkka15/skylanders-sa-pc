"""Call graph over the generated recomp C++: imports reached from given functions.
usage: python -I callgraph.py <generated_dir> <depth> 0xADDR [0xADDR...]"""
import glob, os, re, sys
gen, depth, roots = sys.argv[1], int(sys.argv[2]), [int(a, 16) for a in sys.argv[3:]]
calls, cur = {}, None
for p in glob.glob(os.path.join(gen, '*.cpp')):
    for line in open(p, encoding='utf-8', errors='replace'):
        m = re.match(r'(?:DEFINE_REX_FUNC|PPC_FUNC_IMPL)\((?:__imp__)?sub_([0-9A-F]+)\)', line)
        if m:
            cur = int(m.group(1), 16); calls.setdefault(cur, set()); continue
        if cur is None: continue
        for c in re.findall(r'\b(sub_[0-9A-F]+|__imp__\w+)\(ctx, base\)', line):
            calls[cur].add(c)
        if 'REX_CALL_INDIRECT_FUNC' in line: calls[cur].add('<indirect>')
for r in roots:
    print(f'== sub_{r:08X}')
    seen, frontier = {r}, [(r, 0)]
    while frontier:
        f, dep = frontier.pop(0)
        for c in sorted(calls.get(f, ())):
            if c.startswith('sub_'):
                a = int(c[4:], 16)
                if a not in seen and dep + 1 < depth:
                    seen.add(a); frontier.append((a, dep + 1))
            else:
                print(f'  {"  "*dep}sub_{f:08X} -> {c}')
