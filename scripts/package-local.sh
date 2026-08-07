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

codesign --force --deep --sign - "$app_dir"

print "$app_dir"
