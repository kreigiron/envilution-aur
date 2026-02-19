#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PKGBUILD_FILE="${SCRIPT_DIR}/PKGBUILD"

REPO="ggml-org/llama.cpp"
RELEASE_API="https://api.github.com/repos/${REPO}/releases/latest"
TARBALL_URL="https://github.com/${REPO}/archive/refs/tags"

usage() {
    cat <<EOF
Usage: $0 [version] [options]

Automatically update llama.cpp-cuda PKGBUILD with specified or latest release.

Arguments:
    version               Specific version to update to (e.g., b8087)
                          If omitted, fetches the latest release
                          Format: b<number> (without -1 suffix)

Options:
    -d, --dry-run         Preview changes without modifying file
    -h, --help            Show this help message

Examples:
    $0                    # Update to latest release
    $0 b8087              # Update to specific version b8087
    $0 --dry-run          # Preview latest changes
    $0 b8087 --dry-run    # Preview specific version changes
EOF
    exit 1
}

DRY_RUN=false
TARGET_VERSION=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        -d|--dry-run)
            DRY_RUN=true
            shift
            ;;
        -h|--help)
            usage
            ;;
        *)
            if [[ -z "${TARGET_VERSION}" ]]; then
                TARGET_VERSION="$1"
            else
                echo "Unknown argument: $1" >&2
                usage
            fi
            shift
            ;;
    esac
done

log() {
    local message="$*"
    echo "[INFO] ${message}" >&2
}

error() {
    echo "[ERROR] $*" >&2
    exit 1
}

backup_pkbuild() {
    local timestamp=$(date +%Y%m%d)
    local base_backup_file="${PKGBUILD_FILE}.bak.${timestamp}"
    local backup_file
    
    if [[ ! -f "${base_backup_file}" ]]; then
        backup_file="${base_backup_file}"
        log "Backing up PKGBUILD to ${backup_file}"
    else
        local max_num=0
        for existing_backup in "${base_backup_file}".*; do
            if [[ -f "${existing_backup}" ]]; then
                local num=$(echo "${existing_backup}" | sed -n 's/.*\.bak\.'"${timestamp}"'\.\([0-9]\{3\}\)$/\1/p')
                if [[ -n "${num}" ]] && (( num > max_num )); then
                    max_num=$((num + 1))
                fi
            fi
        done
        
        backup_file="${base_backup_file}.${max_num:0:3}"
        log "Backing up PKGBUILD (incremental #${max_num:0:3}) to ${backup_file}"
    fi
    
    cp "${PKGBUILD_FILE}" "${backup_file}"
}

fetch_latest_release() {
    log "Fetching latest release from ${REPO}..."
    
    local release_info
    release_info=$(curl -s "${RELEASE_API}")
    
    if [[ -z "${release_info}" ]]; then
        error "Failed to fetch release information"
    fi
    
    local tag_name
    tag_name=$(echo "${release_info}" | jq -r '.tag_name')
    
    local target_commitish
    target_commitish=$(echo "${release_info}" | jq -r '.target_commitish')
    
    if [[ -z "${tag_name}" || -z "${target_commitish}" ]]; then
        error "Failed to extract tag_name or target_commitish from release"
    fi
    
    echo "${tag_name}|${target_commitish}"
}

download_tarball_and_sha256() {
    local tag_name="$1"
    local temp_tarball="/tmp/llama.cpp-${tag_name}.tar.gz"
    
    log "Downloading tarball from ${TARBALL_URL}/${tag_name}.tar.gz..."
    
    if ! curl -sL "${TARBALL_URL}/${tag_name}.tar.gz" -o "${temp_tarball}"; then
        error "Failed to download tarball"
    fi
    
    local tarball_sha256
    tarball_sha256=$(sha256sum "${temp_tarball}" | awk '{print $1}')
    
    if [[ -z "${tarball_sha256}" ]]; then
        error "Failed to calculate tarball SHA256 checksum"
    fi
    
    local conf_sha256=$(sha256sum "${SCRIPT_DIR}/llama.cpp.conf" | awk '{print $1}')
    local service_sha256=$(sha256sum "${SCRIPT_DIR}/llama.cpp.service" | awk '{print $1}')
    
    rm -f "${temp_tarball}"
    
    echo "${tarball_sha256}|${conf_sha256}|${service_sha256}"
}

update_pkbuild() {
    local tag_name="$1"
    local build_number="${tag_name#b}"
    build_number="${build_number%-*}"
    local short_commit="${2:0:8}"
    local tarball_sha256="$3"
    local conf_sha256="$4"
    local service_sha256="$5"
    
    log "Updating PKGBUILD..."
    
    if [[ "${DRY_RUN}" == true ]]; then
        log "[DRY RUN] Would update:"
        log "  pkgver=${tag_name}"
        log "  _build_number=${build_number}"
        log "  _commit_id=${short_commit}"
        log "  sha256sums[0]='${tarball_sha256}'"
        log "  sha256sums[1]='${conf_sha256}'"
        log "  sha256sums[2]='${service_sha256}'"
    else
        backup_pkbuild
        
        # Update pkgver
        sed -i "s/pkgver=[a-zA-Z0-9]*/pkgver=${tag_name}/" "${PKGBUILD_FILE}"
        
        # Update _build_number
        sed -i "s/_build_number=[0-9]*/_build_number=${build_number}/" "${PKGBUILD_FILE}"
        
        # Update _commit_id
        sed -i "s/_commit_id=[a-f0-9]*/_commit_id=${short_commit}/" "${PKGBUILD_FILE}"
        
        # Update sha256sums - use awk to replace entire multi-line array with single line
        awk -v tarball_sha256="$tarball_sha256" -v conf_sha256="$conf_sha256" -v service_sha256="$service_sha256" '
        /^sha256sums=/ { 
            print "sha256sums=(\047" tarball_sha256 "\047 \047" conf_sha256 "\047 \047" service_sha256 "\047)"
            in_sha256_array = 1
            next
        }
        in_sha256_array && /^\s*\047[a-f0-9]+\047/ { next }
        in_sha256_array && /^\s*\)/ { in_sha256_array = 0 }
        { print }
        ' "${PKGBUILD_FILE}" > "${PKGBUILD_FILE}.tmp" && mv "${PKGBUILD_FILE}.tmp" "${PKGBUILD_FILE}"
        
        log "  ✓ pkgver updated"
        log "  ✓ _build_number updated"
        log "  ✓ _commit_id updated"
        log "  ✓ sha256sums updated (3 entries)"
    fi
}

main() {
    log "Starting PKGBUILD update automation..."
    
    if [[ ! -f "${PKGBUILD_FILE}" ]]; then
        error "PKGBUILD not found at: ${PKGBUILD_FILE}"
    fi
    
    if ! command -v jq &> /dev/null; then
        error "jq is required but not installed"
    fi
    
    local tag_name target_commitish
    
    if [[ -n "${TARGET_VERSION}" ]]; then
        log "Using specified version: ${TARGET_VERSION}"
        tag_name="${TARGET_VERSION}"
        target_commitish=$(curl -s "https://api.github.com/repos/${REPO}/releases/tags/${tag_name}" | jq -r '.target_commitish')
        if [[ -z "${target_commitish}" ]]; then
            error "Failed to fetch commit for version ${tag_name}"
        fi
    else
        local release_info
        release_info=$(fetch_latest_release)
        tag_name=$(echo "${release_info}" | cut -d'|' -f1)
        target_commitish=$(echo "${release_info}" | cut -d'|' -f2)
    fi
    
    local short_commit="${target_commitish:0:8}"
    log "Latest release: ${tag_name}"
    log "Commit SHA: ${target_commitish}"
    
    local checksums
    checksums=$(download_tarball_and_sha256 "${tag_name}")
    local tarball_sha256 conf_sha256 service_sha256
    tarball_sha256=$(echo "${checksums}" | cut -d'|' -f1)
    conf_sha256=$(echo "${checksums}" | cut -d'|' -f2)
    service_sha256=$(echo "${checksums}" | cut -d'|' -f3)
    log "SHA256 checksums: tarball=${tarball_sha256}, conf=${conf_sha256}, service=${service_sha256}"
    
    update_pkbuild "${tag_name}" "${target_commitish}" "${tarball_sha256}" "${conf_sha256}" "${service_sha256}"
    
    log ""
    log "Update complete!"
    
    if [[ "${DRY_RUN}" == false ]]; then
        log "Review changes and commit: git add PKGBUILD && git commit -m 'Update to ${tag_name}'"
    fi
}

main "$@"
