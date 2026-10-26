#!/bin/zsh
set -eu
cd "${0:A:h:h}"
swiftc -O -module-cache-path work/module-cache Sources/BailongMac/CharacterPanel.swift Sources/BailongMac/AnimatedCharacter.swift Sources/BailongMac/WebPFrames.swift Tests/InputChecks/main.swift -o work/input-checks
work/input-checks
