#!/bin/zsh

set -euo pipefail

script_dir=${0:A:h}
resource_root=${script_dir:h}

fail() {
    print -u2 "Cloudflare Pages deployment failed: $1"
    exit 1
}

usage() {
    cat <<'EOF'
Usage:
  deploy-pages.sh --project-name <name> [options]

Options:
  --project-name <name>  Cloudflare Pages project name.
  --production-branch    Production branch used when creating a missing project.
                         Defaults to main.
  --branch <name>        Optional preview branch name.
  --upload-dir <path>    Worker-only directory. Defaults to ../dist/pages-upload.
  -h, --help             Show this help.

Prerequisites:
  - Node.js and npx are installed.
  - Run `npx wrangler@4 login` before the first deployment.

This command creates an external Cloudflare deployment.
EOF
}

project_name=${VIASIX_PAGES_PROJECT_NAME:-}
production_branch=main
branch=""
upload_dir="$resource_root/dist/pages-upload"

while (( $# > 0 )); do
    case "$1" in
        --project-name)
            (( $# >= 2 )) || fail "--project-name requires a value"
            project_name=$2
            shift 2
            ;;
        --branch)
            (( $# >= 2 )) || fail "--branch requires a value"
            branch=$2
            shift 2
            ;;
        --production-branch)
            (( $# >= 2 )) || fail "--production-branch requires a value"
            production_branch=$2
            shift 2
            ;;
        --upload-dir)
            (( $# >= 2 )) || fail "--upload-dir requires a path"
            upload_dir=$2
            shift 2
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

print -r -- "$project_name" \
    | /usr/bin/grep -Eq '^[a-z0-9][a-z0-9-]{0,57}[a-z0-9]$|^[a-z0-9]$' \
    || fail "project name must use lowercase letters, digits, and internal hyphens"
if [[ -n "$branch" ]]; then
    print -r -- "$branch" \
        | /usr/bin/grep -Eq '^[A-Za-z0-9][A-Za-z0-9._/-]*$' \
        || fail "branch contains unsupported characters"
fi
print -r -- "$production_branch" \
    | /usr/bin/grep -Eq '^[A-Za-z0-9][A-Za-z0-9._/-]*$' \
    || fail "production branch contains unsupported characters"

if [[ "$upload_dir" != /* ]]; then
    upload_dir="$resource_root/$upload_dir"
fi
[[ -d "$upload_dir" && ! -L "$upload_dir" ]] \
    || fail "upload directory is missing or is a symlink"
[[ -f "$upload_dir/_worker.js" && ! -L "$upload_dir/_worker.js" ]] \
    || fail "upload directory does not contain a regular _worker.js"

entry_count=$(
    /usr/bin/find "$upload_dir" -mindepth 1 -maxdepth 1 -print \
        | /usr/bin/wc -l \
        | /usr/bin/tr -d '[:space:]'
)
[[ "$entry_count" == "1" ]] \
    || fail "upload directory must contain only _worker.js"

command -v npx >/dev/null 2>&1 \
    || fail "npx is not installed"

project_list=$(npx --yes wrangler@4 pages project list --json)
if ! print -r -- "$project_list" \
    | /usr/bin/grep -Fq "\"Project Name\": \"$project_name\""; then
    print "Creating Cloudflare Pages project: $project_name"
    npx --yes wrangler@4 pages project create "$project_name" \
        --production-branch "$production_branch"
fi

deploy_command=(
    npx
    --yes
    wrangler@4
    pages
    deploy
    "$upload_dir"
    --project-name
    "$project_name"
    --commit-dirty=true
)
if [[ -n "$branch" ]]; then
    deploy_command+=(--branch "$branch")
fi

print "Deploying worker-only directory to Cloudflare Pages project: $project_name"
"${deploy_command[@]}"
