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

# openapi-generator-cli's argv parser splits on spaces even inside quoted
# paths. Symlink the spec into a no-spaces path and feed that.
SPEC_LINK="$(mktemp -d)/openapi.yaml"
ln -s "$SPEC" "$SPEC_LINK"

npx -y @openapitools/openapi-generator-cli generate \
  -i "$SPEC_LINK" \
  -g swift5 \
  -o "$TMP" \
  --skip-validate-spec \
  --additional-properties=projectName=ScaleUpAPI,responseAs=AsyncAwait,useJsonEncodable=true,useClasses=false \
  > /dev/null

rm -f "$SPEC_LINK"

rm -rf "$OUT"
mkdir -p "$OUT"
cp "$TMP"/ScaleUpAPI/Classes/OpenAPIs/Models/*.swift "$OUT/"

# openapi-generator's Swift5 output depends on its runtime helpers and
# emits unprefixed type names that collide with hand-rolled iOS types
# (Journey/User/UserObjective). Post-process each generated file:
#   - drop the AnyCodable conditional import
#   - drop NumericRule constants
#   - swap Codable+JSONEncodable+Hashable conformance for Codable+Hashable+Sendable
#   - prefix every generated type name (and intra-generated references) with `API`
#     so `Journey` -> `APIJourney`, `PlanCurrent` -> `APIPlanCurrent`, etc.
#   - rename each file accordingly: PlanCurrent.swift -> APIPlanCurrent.swift
echo "Post-processing generated files (Codable cleanup + API-prefix namespace)..."

# Build the list of type names from existing filenames (one type per file).
TYPE_NAMES=$(ls "$OUT"/*.swift | xargs -n1 basename | sed 's/\.swift$//')

# Single Python invocation handles all rewrites atomically.
python3 - "$OUT" "$TYPE_NAMES" <<'PY'
import os, re, sys
out_dir = sys.argv[1]
type_names = sys.argv[2].split()
type_set = set(type_names)

# Word-boundary regex matching any of the generated type names.
type_re = re.compile(r'\b(' + '|'.join(re.escape(t) for t in type_names) + r')\b')

for fname in sorted(os.listdir(out_dir)):
    if not fname.endswith('.swift'):
        continue
    path = os.path.join(out_dir, fname)
    with open(path) as fh:
        src = fh.read()

    # Strip openapi-generator runtime deps.
    src = re.sub(r'#if canImport\(AnyCodable\)\nimport AnyCodable\n#endif\n?', '', src)
    # NumericRule, StringRule, ArrayRule etc. are runtime validators we don't carry.
    src = re.sub(r'^\s*public static let \w+Rule = \w+Rule.*\n', '', src, flags=re.M)
    src = re.sub(
        r'(struct [^:]+:\s*)Codable,\s*JSONEncodable,\s*Hashable',
        r'\1Codable, Hashable, Sendable', src)
    src = re.sub(
        r'(struct [^:]+:\s*)Codable,\s*JSONEncodable',
        r'\1Codable, Sendable', src)

    # Ensure all enums (top-level + nested) conform to Sendable so the
    # parent structs (which are Sendable) can hold them. Cover both
    # String- and Int-backed enums (capstone time_budget_minutes is Int).
    src = re.sub(
        r'(public enum \w+: (?:String|Int|Double): Codable, CaseIterable)(?!,\s*Sendable)',
        r'\1, Sendable', src)
    src = re.sub(
        r'(public enum \w+: (?:String|Int|Double), Codable, CaseIterable)(?!,\s*Sendable)',
        r'\1, Sendable', src)

    # The Swift5 generator emits broken additional-properties handling
    # (uses `String` as a CodingKey, calls .encodeMap/.decodeMap which
    # don't exist). Strip those blocks; we don't carry round-trip support
    # for unknown fields.
    # 1) `public var additionalProperties: [String: AnyCodable] = [:]`
    src = re.sub(r'^\s*public var additionalProperties:.*\n', '', src, flags=re.M)
    # 2) `var [additional]PropertiesContainer = ...container(keyedBy: String.self)` + the .encodeMap/.decodeMap line that follows
    src = re.sub(
        r'\n\s*var additionalPropertiesContainer = encoder\.container\(keyedBy: String\.self\)\n\s*try additionalPropertiesContainer\.encodeMap\(additionalProperties\)\n',
        '\n', src)
    # 3) Decode-side: strip the Set<String>() builder + decodeMap call
    src = re.sub(
        r'\n\s*var nonAdditionalPropertyKeys = Set<String>\(\)\n(?:\s*nonAdditionalPropertyKeys\.insert\("[^"]+"\)\n)*\s*let additionalPropertiesContainer = try decoder\.container\(keyedBy: String\.self\)\n\s*additionalProperties = try additionalPropertiesContainer\.decodeMap\(AnyCodable\.self, excludedKeys: nonAdditionalPropertyKeys\)\n',
        '\n', src)
    # 4) The subscript that backs additionalProperties — locate it and
    #    delete from `public subscript(key: String) -> AnyCodable?` to
    #    the matching closing brace by tracking nesting.
    pat = '    public subscript(key: String) -> AnyCodable? {'
    while pat in src:
        i = src.index(pat)
        # Walk forward, counting braces, until we close the outer one.
        depth = 0
        j = i + len(pat)
        while j < len(src):
            c = src[j]
            if c == '{':
                depth += 1
            elif c == '}':
                if depth == 0:
                    j += 1
                    break
                depth -= 1
            j += 1
        # Eat trailing whitespace/newline so we don't leave a blank.
        end = j
        while end < len(src) and src[end] in ' \t':
            end += 1
        if end < len(src) and src[end] == '\n':
            end += 1
        src = src[:i] + src[end:]
        # Trim adjacent leading blank line if present
        if src[:i].endswith('\n\n'):
            src = src[: i - 1] + src[i:]

    # Rename every reference to a generated type with the API prefix.
    # Skip inner-helper enums like `Source` / `Status` (case-insensitive
    # match against type_set is exact via word-boundary regex).
    src = type_re.sub(lambda m: 'API' + m.group(1), src)

    new_path = os.path.join(out_dir, 'API' + fname)
    with open(new_path, 'w') as fh:
        fh.write(src)
    if new_path != path:
        os.remove(path)
PY

count=$(ls "$OUT"/*.swift | wc -l | tr -d ' ')
echo "Wrote $count Swift type files to $OUT"

rm -rf "$TMP"

echo
echo "Next steps:"
echo "  1. Open ScaleUp.xcodeproj. If 'Generated/OpenAPI' isn't in the project,"
echo "     drag the folder into the ScaleUp target."
echo "  2. Replace hand-rolled DTOs with the generated types incrementally."
echo "     Start with PlanCurrent (the one that surfaced the Phase 4 drift bug)."
