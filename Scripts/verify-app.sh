#!/bin/zsh

set -euo pipefail

script_dir=${0:A:h}
project_root=${script_dir:h}
app_bundle=${1:-"$project_root/dist/ViaSix.app"}
contents_dir="$app_bundle/Contents"
info_plist="$contents_dir/Info.plist"

fail() {
    print -u2 "App verification failed: $1"
    exit 1
}

[[ -d "$app_bundle" ]] || fail "bundle not found at $app_bundle"
[[ -f "$info_plist" ]] || fail "missing Contents/Info.plist"
plutil -lint "$info_plist" >/dev/null

executable_name=$(/usr/libexec/PlistBuddy -c "Print :CFBundleExecutable" "$info_plist")
bundle_identifier=$(/usr/libexec/PlistBuddy -c "Print :CFBundleIdentifier" "$info_plist")
development_region=$(/usr/libexec/PlistBuddy -c "Print :CFBundleDevelopmentRegion" "$info_plist")
package_type=$(/usr/libexec/PlistBuddy -c "Print :CFBundlePackageType" "$info_plist")
minimum_system=$(/usr/libexec/PlistBuddy -c "Print :LSMinimumSystemVersion" "$info_plist")
short_version=$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" "$info_plist")
build_version=$(/usr/libexec/PlistBuddy -c "Print :CFBundleVersion" "$info_plist")
executable_path="$contents_dir/MacOS/$executable_name"
short_version_pattern='^[0-9]+[.][0-9]+[.][0-9]+$'
build_version_pattern='^[0-9]+([.][0-9]+){0,2}$'

[[ "$bundle_identifier" == "com.felix.viasix" ]] || fail "unexpected bundle identifier: $bundle_identifier"
[[ "$development_region" == "zh-Hans" ]] || fail "unexpected development region: $development_region"
[[ "$package_type" == "APPL" ]] || fail "unexpected package type: $package_type"
[[ "$minimum_system" == "14.0" ]] || fail "unexpected minimum macOS version: $minimum_system"
[[ "$short_version" =~ $short_version_pattern ]] || fail "invalid application version: $short_version"
[[ "$build_version" =~ $build_version_pattern ]] || fail "invalid build version: $build_version"
[[ -x "$executable_path" ]] || fail "main executable is missing or not executable"
file "$executable_path" | grep -q "Mach-O" || fail "main executable is not Mach-O"

if [[ -n "${VIASIX_EXPECTED_VERSION:-}" && "$short_version" != "$VIASIX_EXPECTED_VERSION" ]]; then
    fail "expected application version $VIASIX_EXPECTED_VERSION, found $short_version"
fi

if [[ -n "${VIASIX_EXPECTED_BUILD_VERSION:-}" && "$build_version" != "$VIASIX_EXPECTED_BUILD_VERSION" ]]; then
    fail "expected build version $VIASIX_EXPECTED_BUILD_VERSION, found $build_version"
fi

for resource_name in ip.txt ipv6.txt template.json; do
    [[ -f "$contents_dir/Resources/$resource_name" ]] || fail "missing bundled resource: $resource_name"
done
plutil -convert xml1 -o /dev/null "$contents_dir/Resources/template.json"
grep -F -q -- "00000000-0000-0000-0000-000000000000" "$contents_dir/Resources/template.json" \
    || fail "bundled template does not contain the neutral user ID placeholder"
grep -F -q -- "example.com" "$contents_dir/Resources/template.json" \
    || fail "bundled template does not contain the neutral server placeholder"

[[ -f "$contents_dir/Resources/Docs/USER_GUIDE.md" ]] || fail "missing user guide"
[[ -f "$contents_dir/Resources/AppIcon.icns" ]] || fail "missing application icon"
for document_name in CHANGELOG.md LICENSE PRIVACY.md SECURITY.md THIRD_PARTY_NOTICES.md; do
    [[ -f "$contents_dir/Resources/$document_name" ]] \
        || fail "missing bundled document: $document_name"
done
cmp -s "$project_root/LICENSE" "$contents_dir/Resources/LICENSE" \
    || fail "bundled LICENSE does not match the repository copy"

for license_specification in \
    "CloudflareSpeedTest-GPL-3.0.txt 3972dc9744f6499f0f9b2dbf76696f2ae7ad8af9b23dde66d6af86c9dfb36986" \
    "Xray-core-MPL-2.0.txt 1f256ecad192880510e84ad60474eab7589218784b9a50bc7ceee34c2b91f1d5"
do
    license_name=${license_specification%% *}
    expected_digest=${license_specification#* }
    license_path="$contents_dir/Resources/ThirdPartyLicenses/$license_name"
    [[ -f "$license_path" ]] || fail "missing third-party license: $license_name"
    actual_digest=$(shasum -a 256 "$license_path" | awk '{print $1}')
    [[ "$actual_digest" == "$expected_digest" ]] \
        || fail "third-party license checksum mismatch: $license_name"
done

"$project_root/Scripts/check-doc-links.sh" "$contents_dir/Resources" >/dev/null

for forbidden_text in \
    "ipv6""-plan" \
    "ipv6""plan"; do
    if LC_ALL=C grep -R -a -F -q -- "$forbidden_text" "$contents_dir"; then
        fail "forbidden inherited content found in application bundle: $forbidden_text"
    fi
done

if [[ "${VIASIX_ALLOW_LOCAL_PATHS:-0}" != "1" ]] \
    && LC_ALL=C grep -R -a -F -q -- "$project_root" "$contents_dir"; then
    fail "local checkout path leaked into application bundle"
fi

codesign --verify --deep --strict --verbose=2 "$app_bundle"

architectures=$(lipo -archs "$executable_path")
if [[ -n "${VIASIX_EXPECTED_ARCHITECTURE:-}" && " $architectures " != *" $VIASIX_EXPECTED_ARCHITECTURE "* ]]; then
    fail "expected architecture $VIASIX_EXPECTED_ARCHITECTURE, found $architectures"
fi
print "Verified $app_bundle ($bundle_identifier $short_version ($build_version), macOS $minimum_system+, $architectures)"
