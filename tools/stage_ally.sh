#!/bin/bash
# Stages the Linux build for the Ally in H:\skylanders-sa\release\ally (exe, SDK .so files,
# skylanders_sa.toml). Game data (game/) is copied to the Ally separately.
set -eu
B=/root/rex/skylanders-sa/out/build/linux-amd64-relwithdebinfo
L=/root/rex/rexglue-sdk/out/install/linux-amd64/lib
S=/mnt/h/skylanders-sa/release/ally
mkdir -p "$S"
cp "$B/skylanders_sa" "$B/librexgpu-xenosrd.so" "$S/"
cp "$L/librexruntimerd.so" "$L/libTracyClientrd.so" "$S/"
cat > "$S/skylanders_sa.toml" <<'EOF'
# SDK settings (flat key = value). The game finds game/ next to the exe by itself.
gpu_backend = "vulkan"
fps_log = true
log_file = "/home/deck/Games/AddedGames/Skylanders Spyros Adventure/skylanders_sa.log"
log_max_file_size_mb = 50
# Depth readback for the shadow classifier one frame late: the synchronous one stalled the
# Ally's GPU pipeline (~60% of the GPU thread's time).
readback_resolve_addresses_delayed = true
EOF
ls -la "$S"
sha256sum "$S"/skylanders_sa "$S"/*.so | cut -c1-16
