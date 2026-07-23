#!/bin/bash
set -euo pipefail

app=${1:?"usage: $0 /path/to/TextReam.app"}
entitlements=$(codesign -d --entitlements :- "$app" 2>/dev/null)

grep -q '<key>com.apple.security.device.audio-input</key><true/>' <<<"$entitlements"
