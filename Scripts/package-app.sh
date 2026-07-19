#!/bin/zsh

set -euo pipefail

script_dir=${0:A:h}
project_root=${script_dir:h}
configuration=${1:-release}
dist_dir="$project_root/dist"
final_app_bundle="$dist_dir/ViaSix.app"

case "$configuration" in
    debug|release) ;;
    *)
        print -u2 "Unsupported configuration: $configuration (expected debug or release)"
        exit 1
        ;;
esac

build_arguments=(
    --package-path "$project_root"
    -c "$configuration"
    -Xswiftc -DVIASIX_PACKAGED_APP
    -Xlinker -dead_strip
)
swift build "${build_arguments[@]}"
binary_directory=$(swift build "${build_arguments[@]}" --show-bin-path)
binary_path="$binary_directory/ViaSix"

if [[ ! -x "$binary_path" ]]; then
    print -u2 "ViaSix executable was not produced at $binary_path"
    exit 1
fi

mkdir -p "$dist_dir"
package_workspace=$(mktemp -d "$dist_dir/.viasix-package.XXXXXX")
trap 'rm -rf "$package_workspace"' EXIT
app_bundle="$package_workspace/ViaSix.app"
contents_dir="$app_bundle/Contents"

mkdir -p \
    "$contents_dir/MacOS" \
    "$contents_dir/Resources/Docs" \
    "$contents_dir/Resources/ThirdPartyLicenses"
cp "$binary_path" "$contents_dir/MacOS/ViaSix"
cp "$project_root/Packaging/Info.plist" "$contents_dir/Info.plist"
cp "$project_root/Docs/USER_GUIDE.md" "$contents_dir/Resources/Docs/USER_GUIDE.md"
cp "$project_root/CHANGELOG.md" "$contents_dir/Resources/CHANGELOG.md"
cp "$project_root/PRIVACY.md" "$contents_dir/Resources/PRIVACY.md"
cp "$project_root/SECURITY.md" "$contents_dir/Resources/SECURITY.md"
cp "$project_root/LICENSE" "$contents_dir/Resources/LICENSE"
cp "$project_root/THIRD_PARTY_NOTICES.md" "$contents_dir/Resources/THIRD_PARTY_NOTICES.md"
cp \
    "$project_root/ThirdPartyLicenses/CloudflareSpeedTest-GPL-3.0.txt" \
    "$contents_dir/Resources/ThirdPartyLicenses/CloudflareSpeedTest-GPL-3.0.txt"
cp \
    "$project_root/ThirdPartyLicenses/Xray-core-MPL-2.0.txt" \
    "$contents_dir/Resources/ThirdPartyLicenses/Xray-core-MPL-2.0.txt"
"$project_root/Scripts/generate-icon.sh" \
    "$project_root/Packaging/AppIcon.svg" \
    "$contents_dir/Resources/AppIcon.icns"

resource_bundle="$binary_directory/ViaSix_ViaSixCore.bundle"
if [[ ! -d "$resource_bundle" ]]; then
    print -u2 "ViaSixCore resource bundle was not produced at $resource_bundle"
    exit 1
fi

# The app resolves packaged defaults through Bundle.main before SwiftPM's
# development-only Bundle.module fallback, so copy the payload into the normal
# macOS application resources directory.
for resource in "$resource_bundle"/*(N); do
    [[ "${resource:t}" == "Info.plist" ]] && continue
    ditto "$resource" "$contents_dir/Resources/${resource:t}"
done

chmod 755 "$contents_dir/MacOS/ViaSix"
if [[ "$configuration" == "release" ]]; then
    /usr/bin/strip -S -x "$contents_dir/MacOS/ViaSix"
fi
codesign_identity=${VIASIX_CODESIGN_IDENTITY:--}
if [[ "$codesign_identity" == "-" ]]; then
    codesign --force --sign - "$app_bundle"
else
    codesign \
        --force \
        --options runtime \
        --timestamp \
        --sign "$codesign_identity" \
        "$app_bundle"
fi

if [[ "$configuration" == "debug" ]]; then
    VIASIX_ALLOW_LOCAL_PATHS=1 "$project_root/Scripts/verify-app.sh" "$app_bundle"
else
    "$project_root/Scripts/verify-app.sh" "$app_bundle"
fi

previous_app_bundle="$package_workspace/Previous-ViaSix.app"
if [[ -e "$final_app_bundle" ]]; then
    mv "$final_app_bundle" "$previous_app_bundle"
fi
if ! mv "$app_bundle" "$final_app_bundle"; then
    print -u2 "Failed to install packaged application at $final_app_bundle"
    if [[ -e "$previous_app_bundle" ]]; then
        mv "$previous_app_bundle" "$final_app_bundle" \
            || print -u2 "Failed to restore previous application bundle"
    fi
    exit 1
fi
rm -rf "$previous_app_bundle"

print "Created $final_app_bundle"
