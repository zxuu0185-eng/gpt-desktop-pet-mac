#!/bin/zsh
set -eu
cd "${0:A:h:h}"
mkdir -p work/module-cache work/cache
export CLANG_MODULE_CACHE_PATH="$PWD/work/module-cache"
export SWIFTPM_MODULECACHE_OVERRIDE="$PWD/work/module-cache"
swift run --disable-sandbox --cache-path work/cache --scratch-path work/build --manifest-cache local CoreChecks
