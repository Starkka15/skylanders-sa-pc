# Skylanders: Spyro's Adventure — native Linux / PC port

A native version of the Xbox 360 game for Linux (SteamOS on the ROG Ally and Steam Deck)
and Windows, made by static recompilation with the
[ReXGlue SDK](https://github.com/rexglue/rexglue-sdk): the game's PowerPC code is
translated to C++ ahead of time and runs directly, with the SDK providing the Xbox 360
kernel, GPU (Vulkan or Direct3D 12) and audio.

> **About this port.** This port isn't mine to gatekeep. It's a basic starting
> point to build on (features, fixes, polish), not a finished or maintained product. If
> you feel up to it, feel free to continue the work; forks and pull requests are welcome.

**This repository contains none of the game.** You need your own copy of Skylanders:
Spyro's Adventure for the Xbox 360 (title 415608AB), and figures: a real Wii/PS3 Portal
of Power, dumps of your own toys, or both.

The Portal of Power is handled by **[SkyPortal](https://github.com/Starkka15/SkyPortal)**,
a Decky plugin (and a plain Python service on a PC). It passes a real Wii/PS3 portal
through to the game, places figures from dumps on a virtual portal (the two can be mixed),
and dumps the toys standing on a real portal.

> **Early release (0.1.0).** It plays: a locked 30 FPS on a mid-range PC, about 24–30 FPS
> on a base ROG Ally (Z1). It has had little play testing; expect bugs. Reports are
> welcome in Issues, with `skylanders_sa.log`.

## Playing on SteamOS (ROG Ally / Steam Deck)

1. Download `skylanders_sa-linux-x86_64-<version>.tar.gz` from [Releases](../../releases)
   and unpack it to a folder, e.g. `~/Games/Skylanders Spyros Adventure`.
2. Copy the game's files into `game/` next to `skylanders_sa` (`default.xex` at the top
   of `game/`). From a disc image: `python3 tools/xiso_x.py <your disc.iso> game`
   (the script is in this repository).
3. Install SkyPortal in Decky Loader (see its README) and put figure dumps in
   `~/Skylanders` if you use any.
4. Add `skylanders_sa` to Steam as a non-Steam game and start it from Game Mode.

`skylanders_sa.toml` next to the program holds the settings (Vulkan, the log file, the
FPS log). The build targets SteamOS 3.8 (glibc 2.43); older distributions need a build
from source.

## Building

The Linux build is made in WSL 2 or on Linux with Clang 20; the Windows build with Visual
Studio 2022 plus LLVM/Clang 20. Both need CMake 3.25+, Ninja, Python 3 and your own copy
of the game.

1. Build and install the SDK branch this port uses (it carries the fixes the port needs;
   see its commits):
   `git clone --recursive -b skylanders-sa-0.1.0 https://github.com/Starkka15/rexglue-sdk`
2. Put the game's files in `game/files/` (`default.xex` at the top):
   `python tools/xiso_x.py <your disc.iso> game/files`.
3. Generate the code from your `default.xex`: `rexglue codegen skylanders_sa_manifest.toml`
   (writes `generated/`; `config/` holds the extra function entry points the analyzer
   misses).
4. Configure and build, pointing CMake at the SDK install:
   - Linux: `cmake --preset linux-amd64-relwithdebinfo -DCMAKE_C_COMPILER=clang-20
     -DCMAKE_CXX_COMPILER=clang++-20 -Drexglue_DIR=<sdk install>/lib/cmake/rexglue` then
     `cmake --build out/build/linux-amd64-relwithdebinfo`. Copy `librexruntimerd.so`,
     `librexgpu-xenosrd.so` and `libTracyClientrd.so` next to `skylanders_sa`.
   - Windows: `cmake --preset win-amd64-relwithdebinfo -Drexglue_DIR=...` then
     `cmake --build --preset win-amd64-relwithdebinfo`, from a shell with the VS x64
     environment and Clang on PATH (`tools/rexenv.cmd`; edit its paths). Copy the SDK's
     `*rd.dll` files next to `skylanders_sa.exe`. On Windows the game talks to SkyPortal's
     `skyportal.py` over TCP 127.0.0.1:47150.

`tools/wsl_sdk_build.sh`, `tools/wsl_game_build.sh` and `tools/stage_ally.sh` are the
scripts used for the WSL builds; they have local paths to adjust. The generated code is the
game's code translated, so it is never committed: `generated/` and `game/` stay local.
The other scripts in `tools/` are the development tools used for the port (profiling,
memory inspection, frame analysis, finding missed functions).

## Port notes

- `src/shadow_fix.cpp`: the game picks a shadow cascade per screen tile on the CPU from
  the GPU's depth resolve. The port reads that one resolve back to guest memory (the SDK's
  `readback_resolve_addresses`); without it the CPU saw zeros and drew a dark square
  around Spyro. On slower GPUs `readback_resolve_addresses_delayed = true` avoids the
  per-frame stall with one-frame-old depth (the Ally release sets it).
- The Portal of Power goes through the SDK's `XamInputNonController{Get,Set}Raw`
  (`src/kernel/xam/xam_portal.cpp` in the SDK branch) to the SkyPortal service.

## Credits and licenses

Skylanders: Spyro's Adventure was developed by Toys for Bob and published by Activision;
Skylanders and Spyro are trademarks of their owner. This port is not affiliated with or
endorsed by any of them.

The port's own code is GPL-3.0 (see LICENSE). The ReXGlue SDK is BSD-3-Clause and derives
from the Xenia project; it bundles third-party libraries under their own licenses.
