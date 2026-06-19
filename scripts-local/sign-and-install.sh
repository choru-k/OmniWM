#!/bin/zsh
# Build-free re-sign + install of OmniWM with a STABLE self-signed identity, so macOS TCC
# grants (Accessibility + Input Monitoring) survive rebuilds instead of resetting every install.
#
# Run on each Mac once to create the identity; thereafter just re-run after a build to install.
# Assumes dist/OmniWM.app already assembled (see custom/build.md) and `swift build -c release` done.
#
# Usage:  zsh scripts-local/sign-and-install.sh
set -e

IDENTITY="OmniWM Local Signing"
BUNDLE_ID="com.barut.OmniWM"
REPO="${0:A:h:h}"                 # repo root (scripts-local/..)
SIGN_DIR=~/.config/omniwm/signing
APP="$REPO/dist/OmniWM.app"
ENT="$REPO/OmniWM.entitlements"
fresh_identity=0

# 1. Ensure the signing identity exists (create + import if missing). TCC pins the leaf cert hash,
#    which is stable across rebuilds — that's the whole point.
if ! security find-identity -p codesigning | grep -q "$IDENTITY"; then
  echo "==> Creating self-signed identity '$IDENTITY'"
  mkdir -p "$SIGN_DIR"; cd "$SIGN_DIR"
  cat > omniwm-cert.conf <<'EOF'
[ req ]
distinguished_name = dn
x509_extensions = v3
prompt = no
[ dn ]
CN = OmniWM Local Signing
[ v3 ]
basicConstraints = critical,CA:false
keyUsage = critical,digitalSignature
extendedKeyUsage = critical,codeSigning
EOF
  openssl req -x509 -newkey rsa:2048 -nodes -days 3650 -keyout omniwm.key -out omniwm.crt -config omniwm-cert.conf 2>/dev/null
  # macOS `security` can't read OpenSSL 3's default p12 MAC — must use -legacy AND a real password.
  openssl pkcs12 -export -legacy -out omniwm.p12 -inkey omniwm.key -in omniwm.crt -passout pass:omniwm 2>/dev/null
  chmod 600 omniwm.key omniwm.p12
  security import omniwm.p12 -k ~/Library/Keychains/login.keychain-db -P omniwm -T /usr/bin/codesign
  fresh_identity=1
  # find-identity will list it as CSSMERR_TP_NOT_TRUSTED — that's expected; codesign signs with it fine.
else
  echo "==> Identity '$IDENTITY' already present"
fi

# 2. Sign omniwmctl, the main binary, then the bundle (inside-out), with entitlements.
[ -d "$APP" ] || { echo "ERROR: $APP not found — assemble dist/OmniWM.app first (see custom/build.md)"; exit 1; }
echo "==> Signing"
osascript -e 'quit app "OmniWM"' 2>/dev/null || true
sleep 1
codesign --force --sign "$IDENTITY" --entitlements "$ENT" "$APP/Contents/MacOS/omniwmctl"
codesign --force --sign "$IDENTITY" --entitlements "$ENT" "$APP/Contents/MacOS/OmniWM"
codesign --force --sign "$IDENTITY" --entitlements "$ENT" "$APP"
codesign -dvvv "$APP" 2>&1 | grep -i Authority

# 3. Install + symlink the CLI.
echo "==> Installing to /Applications"
ditto "$APP" /Applications/OmniWM.app
ln -sf /Applications/OmniWM.app/Contents/MacOS/omniwmctl /opt/homebrew/bin/omniwmctl

# 4. Only a brand-new identity needs a TCC reset + one-time re-grant.
if [ "$fresh_identity" = 1 ]; then
  tccutil reset Accessibility "$BUNDLE_ID" >/dev/null
  tccutil reset ListenEvent "$BUNDLE_ID" >/dev/null
  echo ""
  echo "==> NEW identity: grant ONCE in System Settings > Privacy & Security:"
  echo "      - Accessibility   -> enable OmniWM (tiling/resize)"
  echo "      - Input Monitoring -> enable OmniWM (F15 chord layer)"
  echo "    After this, rebuilds signed with the same identity keep the grants."
else
  echo "==> Done. Grants preserved (same identity)."
fi

open -a /Applications/OmniWM.app
