#!/bin/bash
# Creates a self-signed code-signing certificate in your login keychain.
# build.sh picks it up automatically. With a stable certificate, macOS
# remembers the Accessibility permission across rebuilds (with ad-hoc
# signing every build looks like a brand-new app).
#
# The certificate is only used locally to sign your own build. Remove it
# any time from Keychain Access ("ScrollFlip Local Signing").
set -euo pipefail

NAME="ScrollFlip Local Signing"
if security find-identity -p codesigning | grep -q "\"$NAME\""; then
    echo "✔ Certificate \"$NAME\" already exists."
    exit 0
fi

TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

cat > "$TMP/cert.cnf" <<CNF
[req]
distinguished_name = dn
x509_extensions = ext
prompt = no
[dn]
CN = $NAME
[ext]
basicConstraints = critical,CA:false
keyUsage = critical,digitalSignature
extendedKeyUsage = critical,codeSigning
CNF

openssl req -x509 -newkey rsa:2048 -nodes -days 3650 \
    -config "$TMP/cert.cnf" -keyout "$TMP/key.pem" -out "$TMP/cert.pem" 2>/dev/null
PASS=$(openssl rand -hex 16)
openssl pkcs12 -export -legacy -inkey "$TMP/key.pem" -in "$TMP/cert.pem" \
    -out "$TMP/cert.p12" -passout "pass:$PASS" 2>/dev/null \
  || openssl pkcs12 -export -inkey "$TMP/key.pem" -in "$TMP/cert.pem" \
    -out "$TMP/cert.p12" -passout "pass:$PASS"
security import "$TMP/cert.p12" -k ~/Library/Keychains/login.keychain-db \
    -P "$PASS" -T /usr/bin/codesign

echo "✔ Certificate \"$NAME\" created. Now run ./build.sh install"
