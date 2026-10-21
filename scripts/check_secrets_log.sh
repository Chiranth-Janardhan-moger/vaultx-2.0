#!/usr/bin/env bash
# Bash script for CI secret leak & plaintext logging detection
set -euo pipefail

SEARCH_DIR="${1:-lib}"
echo "==> Scanning $SEARCH_DIR for accidental plaintext secret logging..."

# Pattern matches unexempted print/log statements containing sensitive variable names
# Exemption: lines containing "// security-exempt"
VIOLATIONS=$(grep -rnE "(print|debugPrint|log)\s*\(.*(password|masterKey|privateKey|sharedSecret|seedPhrase|cardNumber|pin|cvv|secret).*\)" "$SEARCH_DIR" 2>/dev/null | grep -v "// security-exempt" || true)

if [ -n "$VIOLATIONS" ]; then
  echo "ERROR: Detected sensitive logging violations:"
  echo "$VIOLATIONS"
  exit 1
fi

echo "SUCCESS: Zero plaintext secrets detected in $SEARCH_DIR."
exit 0
