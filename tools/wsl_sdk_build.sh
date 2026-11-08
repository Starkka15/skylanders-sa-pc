#!/bin/bash
# Syncs H:\rexglue-sdk into WSL ext4 (/root/rex/rexglue-sdk) and builds + installs the Linux SDK.
# Configured once with: cmake --preset linux-amd64 -DCMAKE_C_COMPILER=clang-20 -DCMAKE_CXX_COMPILER=clang++-20
set -u
rsync -a --exclude out/ --exclude .git/ /mnt/h/rexglue-sdk/ /root/rex/rexglue-sdk/ || exit 1
cd /root/rex/rexglue-sdk || exit 1
timeout 5400 cmake --build out/build/linux-amd64 --config RelWithDebInfo --target install -j 12 > /root/rex/sdk-build.log 2>&1
rc=$?
echo "sdk rc=$rc"
grep -m10 -E 'error:|FAILED' /root/rex/sdk-build.log
tail -2 /root/rex/sdk-build.log
exit $rc
