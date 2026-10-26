#!/bin/zsh
set -eu
cd "${0:A:h:h}"
mkdir -p work/module-cache
swiftc -O -module-cache-path work/module-cache Sources/BailongMac/WebPFrames.swift Tests/AnimationChecks/main.swift -o work/animation-checks
work/animation-checks "${1:-work/materials}"
