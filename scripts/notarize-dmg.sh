#!/bin/zsh
set -euo pipefail

if (( $# != 1 )); then
    print -u2 "Usage: $0 /path/to/MiCoding-version.dmg"
    exit 1
fi

dmg_path=$1
key_id=${APP_STORE_CONNECT_API_KEY_ID:-}
issuer_id=${APP_STORE_CONNECT_API_ISSUER_ID:-}
encoded_key=${APP_STORE_CONNECT_API_KEY_P8_BASE64:-}

if [[ ! -f "$dmg_path" ]]; then
    print -u2 "DMG not found: $dmg_path"
    exit 1
fi
if [[ -z "$key_id" || -z "$issuer_id" || -z "$encoded_key" ]]; then
    print -u2 "App Store Connect notarization credentials are incomplete."
    exit 1
fi

temporary_dir=$(mktemp -d "${TMPDIR:-/tmp}/micoding-notary.XXXXXX")
key_path="$temporary_dir/AuthKey_$key_id.p8"
cleanup() {
    rm -rf -- "$temporary_dir"
}
trap cleanup EXIT

print -rn -- "$encoded_key" | base64 --decode > "$key_path"
chmod 600 "$key_path"

xcrun notarytool submit "$dmg_path" \
    --key "$key_path" \
    --key-id "$key_id" \
    --issuer "$issuer_id" \
    --wait
xcrun stapler staple "$dmg_path"
xcrun stapler validate "$dmg_path"
shasum -a 256 "$dmg_path" > "$dmg_path.sha256"
