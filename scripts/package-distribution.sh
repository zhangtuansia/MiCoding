#!/bin/zsh
set -euo pipefail

project_dir=${0:A:h:h}
app_name="MiCoding.app"
bundle_identifier="io.xiaomiremote.studio"
output_dir=${MICODING_OUTPUT_DIR:-"$project_dir/build/distribution"}
app_dir="$output_dir/$app_name"
staging_dir="$output_dir/dmg-root"
source_info_plist="$project_dir/Resources/Info.plist"
version=${MICODING_VERSION:-$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$source_info_plist")}
build_number=${MICODING_BUILD_NUMBER:-$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "$source_info_plist")}
signing_identity=${MICODING_CODESIGN_IDENTITY:--}
architectures=${MICODING_ARCHS:-"arm64 x86_64"}

if [[ ! "$version" =~ '^[0-9]+([.][0-9A-Za-z-]+)*$' ]]; then
    print -u2 "Invalid MiCoding version: $version"
    exit 1
fi
if [[ ! "$build_number" =~ '^[0-9]+([.][0-9]+)*$' ]]; then
    print -u2 "Invalid MiCoding build number: $build_number"
    exit 1
fi

dmg_path="$output_dir/MiCoding-$version.dmg"
checksum_path="$dmg_path.sha256"
contents_dir="$app_dir/Contents"

cd "$project_dir"
swift "$project_dir/scripts/generate-app-icon.swift"
iconutil -c icns "$project_dir/Resources/AppIcon-official.iconset" \
    -o "$project_dir/Resources/AppIcon-official.icns"

build_arguments=(-c release)
for architecture in ${(z)architectures}; do
    build_arguments+=(--arch "$architecture")
done
swift build "${build_arguments[@]}"
product_dir=$(swift build "${build_arguments[@]}" --show-bin-path)

rm -rf -- "$app_dir" "$staging_dir"
rm -f -- "$dmg_path" "$checksum_path"
mkdir -p "$contents_dir/MacOS" "$contents_dir/Resources" "$staging_dir"

cp "$product_dir/XiaomiRemoteStudio" "$contents_dir/MacOS/XiaomiRemoteStudio"
cp "$source_info_plist" "$contents_dir/Info.plist"
cp "$project_dir/Resources/AppIcon-official.icns" \
    "$contents_dir/Resources/AppIcon-official.icns"
cp "$project_dir/THIRD_PARTY_NOTICES.md" \
    "$contents_dir/Resources/THIRD_PARTY_NOTICES.md"

resource_bundles=("$product_dir"/*.bundle(N))
for resource_bundle in $resource_bundles; do
    cp -R "$resource_bundle" "$contents_dir/Resources/"
done

plutil -replace CFBundleShortVersionString -string "$version" "$contents_dir/Info.plist"
plutil -replace CFBundleVersion -string "$build_number" "$contents_dir/Info.plist"
chmod +x "$contents_dir/MacOS/XiaomiRemoteStudio"

if [[ "$signing_identity" == "-" ]]; then
    codesign --force --deep --sign - --options runtime \
        --requirements "=designated => identifier \"$bundle_identifier\"" \
        "$app_dir"
    print "Signed app ad-hoc. Configure Developer ID secrets for public distribution."
else
    codesign --force --deep --sign "$signing_identity" \
        --options runtime --timestamp "$app_dir"
    print "Signed app with $signing_identity."
fi
codesign --verify --deep --strict --verbose=2 "$app_dir"

/usr/bin/ditto "$app_dir" "$staging_dir/$app_name"
ln -s /Applications "$staging_dir/Applications"
hdiutil create \
    -volname "MiCoding $version" \
    -srcfolder "$staging_dir" \
    -format UDZO \
    -imagekey zlib-level=9 \
    -ov \
    "$dmg_path"

if [[ "$signing_identity" != "-" ]]; then
    codesign --force --sign "$signing_identity" --timestamp "$dmg_path"
    codesign --verify --verbose=2 "$dmg_path"
fi

rm -rf -- "$staging_dir"
(
    cd "$output_dir"
    shasum -a 256 "${dmg_path:t}"
) > "$checksum_path"
hdiutil verify "$dmg_path"
print "$dmg_path"
