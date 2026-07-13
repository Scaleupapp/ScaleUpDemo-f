#!/bin/bash
# One-command TestFlight pipeline for the ScaleUp D2C iOS app.
# Requires ASC_ISSUER_ID in the environment (everything else is auto-detected).
#
#   ASC_ISSUER_ID=<uuid> ./appstore/testflight.sh
#
# Steps: archive (auto-signing via API key, registers bundle ID) → ensure
# distribution profile + app record (ASC API) → export .ipa (manual signing
# with that profile) → upload to TestFlight.
set -euo pipefail

cd "$(dirname "$0")/.."
ROOT="$(pwd)"
export PATH="/opt/homebrew/bin:$PATH"

# --- Config (auto-detected from this machine) ---
export ASC_KEY_ID="${ASC_KEY_ID:-A4MNMMCCVB}"
export ASC_TEAM_ID="${ASC_TEAM_ID:-NK5P69WG2H}"
export APP_BUNDLE_ID="${APP_BUNDLE_ID:-com.scaleupapp.ios}"
export APP_NAME="${APP_NAME:-ScaleUp: AI Career Coach}"
export APP_SKU="${APP_SKU:-scaleup-ios-001}"
export PROFILE_NAME="${PROFILE_NAME:-ScaleUp iOS AppStore}"
NODE="${NODE:-/opt/homebrew/bin/node}"
command -v "$NODE" >/dev/null 2>&1 || NODE="$(command -v node)"

# Locate the API key (.p8). Standard locations first.
KEY_PATH=""
for p in \
  "$HOME/.appstoreconnect/private_keys/AuthKey_${ASC_KEY_ID}.p8" \
  "$HOME/.private_keys/AuthKey_${ASC_KEY_ID}.p8" \
  "$HOME/Downloads/Code & Dev/AuthKey_${ASC_KEY_ID}.p8"; do
  [ -f "$p" ] && KEY_PATH="$p" && break
done
export ASC_KEY_PATH="$KEY_PATH"

if [ -z "${ASC_ISSUER_ID:-}" ]; then
  echo "ERROR: ASC_ISSUER_ID is not set."
  echo "Get it from App Store Connect → Users and Access → Integrations → App Store Connect API (top of page)."
  exit 2
fi
if [ -z "$ASC_KEY_PATH" ]; then echo "ERROR: AuthKey_${ASC_KEY_ID}.p8 not found."; exit 2; fi

echo "── Step 1/4: archive (registers bundle ID + auto-signs via API key) ──"
xcodegen generate >/dev/null
ARCHIVE="$ROOT/build/ScaleUp.xcarchive"
rm -rf "$ARCHIVE"
xcodebuild -project ScaleUp.xcodeproj -scheme ScaleUp \
  -configuration Release -sdk iphoneos -archivePath "$ARCHIVE" \
  -allowProvisioningUpdates \
  -authenticationKeyPath "$ASC_KEY_PATH" \
  -authenticationKeyID "$ASC_KEY_ID" \
  -authenticationKeyIssuerID "$ASC_ISSUER_ID" \
  DEVELOPMENT_TEAM="$ASC_TEAM_ID" \
  archive

echo "── Step 2/4: ensure bundle ID, distribution profile, app record ──"
APP_CHECK="$("$NODE" appstore/asc.js)"
echo "$APP_CHECK"

echo "── Step 3/4: export signed .ipa (manual signing) ──"
EXPORT_DIR="$ROOT/build/export"
rm -rf "$EXPORT_DIR"
xcodebuild -exportArchive -archivePath "$ARCHIVE" \
  -exportOptionsPlist appstore/ExportOptions.plist \
  -exportPath "$EXPORT_DIR"

IPA="$(ls "$EXPORT_DIR"/*.ipa | head -1)"
echo "✓ IPA exported: $IPA"

if echo "$APP_CHECK" | grep -q "APP RECORD MISSING"; then
  echo ""
  echo "⏸  Stopping before upload — the app record must be created once (see above)."
  echo "   The signed IPA is ready at: $IPA"
  echo "   After creating the app record, run:  ASC_ISSUER_ID=$ASC_ISSUER_ID ./appstore/testflight.sh"
  exit 0
fi

echo "── Step 4/4: upload to TestFlight ($IPA) ──"
set +e
UPLOAD_LOG="$(xcrun altool --upload-app -f "$IPA" -t ios \
  --apiKey "$ASC_KEY_ID" --apiIssuer "$ASC_ISSUER_ID" 2>&1)"
UPLOAD_STATUS=$?
set -e
echo "$UPLOAD_LOG"

# altool has been observed to exit 0 even when it reports a validation
# failure, so don't trust the exit code alone — scan the output too.
if [ "$UPLOAD_STATUS" -ne 0 ] || echo "$UPLOAD_LOG" | grep -qE "UPLOAD FAILED|Failed to upload package|ERROR:"; then
  echo "❌ Upload to TestFlight FAILED — see the altool output above for the real cause. Not claiming success."
  exit 1
fi

echo "✅ Uploaded to TestFlight. It will appear under the app after Apple finishes processing (~5–15 min)."
