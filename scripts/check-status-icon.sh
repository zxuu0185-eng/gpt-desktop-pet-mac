#!/bin/zsh
set -eu
cd "${0:A:h:h}"
fixture="work/status-icon-check.app"
mkdir -p "$fixture/Contents/MacOS" "$fixture/Contents/Resources"
icon="${1:-Resources/Local/BAILONG_GPT_TOPBAR_V2_SIMPLE.png}"
if [[ ! -f "$icon" ]]; then
  print "SKIP: optional local character icon is not distributed; built-in symbol is used."
  exit 0
fi
cp "$icon" "$fixture/Contents/Resources/BAILONG_GPT_TOPBAR_V2_SIMPLE.png"
swiftc -parse-as-library -module-cache-path work/module-cache Sources/BailongMac/StatusBarIcon.swift Tests/StatusBarIconChecks/main.swift -o "$fixture/Contents/MacOS/check"
"$fixture/Contents/MacOS/check"
