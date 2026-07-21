#!/bin/zsh

set -euo pipefail

umask 077

script_dir=${0:A:h}
resource_root=${script_dir:h}

fail() {
    print -u2 "Cloudflare Pages preparation failed: $1"
    exit 1
}

usage() {
    cat <<'EOF'
Usage:
  prepare-deploy.sh --uuid <UUID> [options]
  prepare-deploy.sh --uuid-file <path> [options]

Options:
  --uuid <UUID>          VLESS UUID v4. Can also use VIASIX_PAGES_UUID.
  --uuid-file <path>     Read the UUID from the first line of a local file.
  --source <path>        Alternative local worker template.
                         Defaults to ../worker-template.js.
  --output-dir <path>    Worker-only upload directory.
                         Defaults to ../dist/pages-upload.
  --no-archive           Do not create the drag-and-drop ZIP archive.
  -h, --help             Show this help.

This implementation connects directly to requested TCP destinations and does
not support or require ProxyIP.
EOF
}

validate_uuid() {
    print -r -- "$1" \
        | /usr/bin/grep -Eq '^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$'
}

uuid=${VIASIX_PAGES_UUID:-}
uuid_file=""
source_path=${VIASIX_PAGES_WORKER_SOURCE:-$resource_root/worker-template.js}
output_dir="$resource_root/dist/pages-upload"
create_archive=true

while (( $# > 0 )); do
    case "$1" in
        --uuid)
            (( $# >= 2 )) || fail "--uuid requires a value"
            uuid=$2
            shift 2
            ;;
        --uuid-file)
            (( $# >= 2 )) || fail "--uuid-file requires a path"
            uuid_file=$2
            shift 2
            ;;
        --source)
            (( $# >= 2 )) || fail "--source requires a value"
            source_path=$2
            shift 2
            ;;
        --output-dir)
            (( $# >= 2 )) || fail "--output-dir requires a path"
            output_dir=$2
            shift 2
            ;;
        --no-archive)
            create_archive=false
            shift
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            fail "unknown argument: $1"
            ;;
    esac
done

if [[ -n "$uuid_file" ]]; then
    [[ -f "$uuid_file" && ! -L "$uuid_file" ]] \
        || fail "UUID file must be a regular, non-symlink file"
    uuid=$(/usr/bin/sed -n '1p' "$uuid_file")
fi

uuid=$(print -r -- "$uuid" | /usr/bin/tr '[:upper:]' '[:lower:]')
validate_uuid "$uuid" || fail "UUID must be a valid UUID v4"

if [[ "$source_path" != /* ]]; then
    source_path="$resource_root/$source_path"
fi
[[ -f "$source_path" && ! -L "$source_path" ]] \
    || fail "worker template must be a regular, non-symlink file"
/usr/bin/grep -Fqx \
    'const USER_ID = "00000000-0000-4000-8000-000000000000";' \
    "$source_path" \
    || fail "worker template does not contain the expected UUID placeholder"
/usr/bin/grep -Fq 'import { connect } from "cloudflare:sockets";' "$source_path" \
    || fail "worker template does not use Cloudflare TCP sockets"

if [[ "$output_dir" != /* ]]; then
    output_dir="$resource_root/$output_dir"
fi
/bin/mkdir -p -m 700 "$output_dir"
[[ -d "$output_dir" && ! -L "$output_dir" ]] \
    || fail "output directory is missing or is a symlink"
archive_directory=${output_dir:h}
[[ -d "$archive_directory" && ! -L "$archive_directory" ]] \
    || fail "archive directory is missing or is a symlink"

temp_root=$(getconf DARWIN_USER_TEMP_DIR 2>/dev/null || print -r -- "${TMPDIR:-/tmp}")
[[ -d "$temp_root" && ! -L "$temp_root" ]] \
    || fail "temporary directory is missing or unsafe: $temp_root"
work_directory=$(mktemp -d "${temp_root%/}/com.felix.viasix.pages.XXXXXX") \
    || fail "cannot create a private temporary directory"

cleanup() {
    if [[ -d "$work_directory" && ! -L "$work_directory" \
        && "$work_directory" == "${temp_root%/}/com.felix.viasix.pages."* ]]; then
        /bin/rm -rf -- "$work_directory"
    fi
}
trap cleanup EXIT

prepared_worker="$work_directory/_worker.js"
/usr/bin/awk -v uuid="$uuid" '
    $0 == "const USER_ID = \"00000000-0000-4000-8000-000000000000\";" {
        print "const USER_ID = \"" uuid "\";"
        uuid_written = 1
        next
    }
    { print }
    END {
        if (uuid_written != 1) exit 2
    }
' "$source_path" > "$prepared_worker"

[[ -s "$prepared_worker" ]] || fail "prepared _worker.js is empty"
/usr/bin/grep -Fq "const USER_ID = \"$uuid\";" "$prepared_worker" \
    || fail "prepared _worker.js does not contain the requested UUID"
if /usr/bin/grep -Eq 'proxyIPs|proxyIP|proxyip' "$prepared_worker"; then
    fail "prepared _worker.js unexpectedly contains ProxyIP logic"
fi
/bin/chmod 600 "$prepared_worker"

output_worker="$output_dir/_worker.js"
if [[ -e "$output_worker" && ( ! -f "$output_worker" || -L "$output_worker" ) ]]; then
    fail "output _worker.js exists and is not a regular file"
fi
/bin/mv -f "$prepared_worker" "$output_worker"
/bin/chmod 600 "$output_worker"

if [[ "$create_archive" == true ]]; then
    archive_name="viasix-cloudflare-pages.zip"
    prepared_archive="$work_directory/$archive_name"
    /usr/bin/zip -j -q "$prepared_archive" "$output_worker"
    /usr/bin/unzip -Z1 "$prepared_archive" \
        | /usr/bin/grep -Fxq '_worker.js' \
        || fail "archive does not contain _worker.js at its root"
    output_archive="$archive_directory/$archive_name"
    if [[ -e "$output_archive" && ( ! -f "$output_archive" || -L "$output_archive" ) ]]; then
        fail "output archive exists and is not a regular file"
    fi
    /bin/mv -f "$prepared_archive" "$output_archive"
    /bin/chmod 600 "$output_archive"
fi

worker_sha256=$(/usr/bin/shasum -a 256 "$output_worker" | /usr/bin/awk '{print $1}')
print "Prepared direct-TCP Cloudflare Pages worker: $output_worker"
print "Prepared worker SHA-256: $worker_sha256"
if [[ "$create_archive" == true ]]; then
    print "Prepared dashboard upload archive: $archive_directory/viasix-cloudflare-pages.zip"
fi
print "ProxyIP is disabled and not required by this worker."
