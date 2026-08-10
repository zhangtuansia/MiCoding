#!/bin/zsh
set -euo pipefail

project_dir=${0:A:h:h}
app_name="MiCoding.app"
output_dir="$project_dir/build"
app_dir="$output_dir/$app_name"
legacy_app_dir="$output_dir/Xiaomi Remote Studio.app"
contents_dir="$app_dir/Contents"

cd "$project_dir"
swift "$project_dir/scripts/generate-app-icon.swift"
iconutil -c icns "$project_dir/Resources/AppIcon-official.iconset" -o "$project_dir/Resources/AppIcon-official.icns"
swift build -c debug

if [[ -d "$app_dir" ]]; then
    rm -rf -- "$app_dir"
fi
if [[ -d "$legacy_app_dir" ]]; then
    rm -rf -- "$legacy_app_dir"
fi
mkdir -p "$contents_dir/MacOS" "$contents_dir/Resources"
cp "$project_dir/.build/debug/XiaomiRemoteStudio" "$contents_dir/MacOS/XiaomiRemoteStudio"
cp "$project_dir/Resources/Info.plist" "$contents_dir/Info.plist"
cp "$project_dir/Resources/AppIcon-official.icns" "$contents_dir/Resources/AppIcon-official.icns"
cp "$project_dir/THIRD_PARTY_NOTICES.md" "$contents_dir/Resources/THIRD_PARTY_NOTICES.md"
resource_bundles=("$project_dir"/.build/debug/*.bundle(N))
for resource_bundle in $resource_bundles; do
    cp -R "$resource_bundle" "$contents_dir/Resources/"
done
chmod +x "$contents_dir/MacOS/XiaomiRemoteStudio"

signing_identity=${MICODING_CODESIGN_IDENTITY:-}
if [[ -z "$signing_identity" ]]; then
    candidate_text=$(
        security find-identity -v -p codesigning 2>/dev/null \
            | rg '"Apple Development:' \
            | rg -v 'CSSMERR_' \
            | rg -o '[0-9A-F]{40}' \
            || true
    )
    signing_identity="-"
    signing_candidates=(${(f)candidate_text})
    for candidate in $signing_candidates; do
        # find-identity can still surface a leaf whose issuing certificate was
        # revoked. Sign once and ask Gatekeeper for the concrete chain error;
        # a plain “rejected” is expected for an unnotarized local debug build.
        if codesign --force --deep --sign "$candidate" "$app_dir" >/dev/null 2>&1; then
            assessment=$(spctl --assess --type execute --verbose=4 "$app_dir" 2>&1 || true)
            if ! print -r -- "$assessment" | rg -q 'CSSMERR_TP_CERT_REVOKED|certificate revoked'; then
                signing_identity="$candidate"
                break
            fi
        fi
    done
fi

if [[ "$signing_identity" == "-" ]]; then
    # Ad-hoc is a portable fallback, but TCC still adds the changing cdhash to
    # privacy grants. Use a persistent Apple Development identity whenever one
    # is available so Input Monitoring survives local app updates.
    codesign --force --deep --sign - \
        --requirements '=designated => identifier "io.xiaomiremote.studio"' \
        "$app_dir"
    print "Signed ad-hoc; privacy permissions may need renewal after rebuilds."
else
    codesign --force --deep --sign "$signing_identity" "$app_dir"
    print "Signed with stable local development identity $signing_identity."
fi

print "$app_dir"
