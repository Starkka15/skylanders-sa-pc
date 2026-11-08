#!/bin/bash
# Syncs H:\skylanders-sa (sources + generated code, no game data/logs/out) into WSL ext4 and
# builds the Linux RelWithDebInfo binary at /root/rex/skylanders-sa/out/build/linux-amd64-relwithdebinfo.
set -u
# The SDK installs its codegen CLI (rex::rexglue) only for Release; this box builds the SDK in
# RelWithDebInfo, so build the Release CLI once and register it by hand.
I=/root/rex/rexglue-sdk/out/install/linux-amd64
if [ ! -f "$I/lib/cmake/rexglue/rexglueTargets-release.cmake" ]; then
  if [ ! -x /root/rex/rexglue-sdk/out/linux-amd64/Release/rexglue ]; then
    (cd /root/rex/rexglue-sdk && cmake --build out/build/linux-amd64 --config Release --target rexglue -j 12) \
      > /root/rex/cli-build.log 2>&1 || { tail -20 /root/rex/cli-build.log; exit 1; }
  fi
  mkdir -p "$I/bin"
  cp /root/rex/rexglue-sdk/out/linux-amd64/Release/rexglue "$I/bin/"
  cat > "$I/lib/cmake/rexglue/rexglueTargets-release.cmake" <<'EOF'
# Hand-written by tools/wsl_game_build.sh: only the codegen CLI is built in Release on this box.
set_property(TARGET rex::rexglue APPEND PROPERTY IMPORTED_CONFIGURATIONS RELEASE)
set_target_properties(rex::rexglue PROPERTIES IMPORTED_LOCATION_RELEASE "${_IMPORT_PREFIX}/bin/rexglue")
EOF
  rm -rf /root/rex/skylanders-sa/out
fi
mkdir -p /root/rex/skylanders-sa
rsync -a --delete --exclude out/ --exclude .git/ --exclude /game/ --exclude /logs/ --exclude /testlib/ \
  --exclude release/ --exclude decky-skyportal/ /mnt/h/skylanders-sa/ /root/rex/skylanders-sa/ || exit 1
cd /root/rex/skylanders-sa || exit 1
# Codegen needs the XEX (only that file; game data stays out of the WSL copy).
mkdir -p game/files && rsync -a /mnt/h/skylanders-sa/game/files/default.xex game/files/ || exit 1
if [ ! -f out/build/linux-amd64-relwithdebinfo/build.ninja ]; then
  cmake --preset linux-amd64-relwithdebinfo -DCMAKE_C_COMPILER=clang-20 -DCMAKE_CXX_COMPILER=clang++-20 \
    -Drexglue_DIR=/root/rex/rexglue-sdk/out/install/linux-amd64/lib/cmake/rexglue \
    > /root/rex/game-configure.log 2>&1 || { tail -30 /root/rex/game-configure.log; exit 1; }
fi
timeout 5400 cmake --build out/build/linux-amd64-relwithdebinfo -j 12 > /root/rex/game-build.log 2>&1
rc=$?
echo "game rc=$rc"
grep -m15 -E 'error:|FAILED' /root/rex/game-build.log
tail -2 /root/rex/game-build.log
exit $rc
