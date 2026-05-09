#!/usr/bin/env bash
# Regenerate Swift types from the backend's openapi.yaml.
# Run after pulling backend changes that touch openapi.yaml.
#
# Output: ScaleUp/Generated/OpenAPI/*.swift
#
# Requires: node + npx (for openapi-generator-cli) + Java 11+.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SPEC="${REPO_ROOT}/../ScaleUpDemo/scaleup-backend/openapi.yaml"
OUT="${REPO_ROOT}/ScaleUp/Generated/OpenAPI"
TMP="$(mktemp -d)"

if [[ ! -f "$SPEC" ]]; then
  echo "ERROR: spec not found at $SPEC"
  echo "Make sure ScaleUpDemo/scaleup-backend is checked out alongside ScaleUpDemo-f."
  exit 1
fi

echo "Generating Swift types from: $SPEC"

npx -y @openapitools/openapi-generator-cli generate \
  -i "$SPEC" \
  -g swift5 \
  -o "$TMP" \
  --skip-validate-spec \
  --additional-properties=projectName=ScaleUpAPI,responseAs=AsyncAwait,useJsonEncodable=true,useClasses=false \
  > /dev/null

rm -rf "$OUT"
mkdir -p "$OUT"
cp "$TMP"/ScaleUpAPI/Classes/OpenAPIs/Models/*.swift "$OUT/"

count=$(ls "$OUT"/*.swift | wc -l | tr -d ' ')
echo "Wrote $count Swift type files to $OUT"

rm -rf "$TMP"

echo
echo "Next steps:"
echo "  1. Open ScaleUp.xcodeproj. If 'Generated/OpenAPI' isn't in the project,"
echo "     drag the folder into the ScaleUp target."
echo "  2. Replace hand-rolled DTOs with the generated types incrementally."
echo "     Start with PlanCurrent (the one that surfaced the Phase 4 drift bug)."
