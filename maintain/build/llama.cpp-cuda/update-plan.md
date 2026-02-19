# llama.cpp-cuda PKGBUILD Update Automation Plan

## Overview
Automate the process of updating the Arch Linux PKGBUILD with the latest llama.cpp release version and SHA256 checksums.

## Current PKGBUILD Structure
```bash
pkgname=llama.cpp-cuda
_pkgname="${pkgname%-cuda}"
pkgver=b7376
pkgrel=1
_build_number=7376
_commit_id=380b4c9
```

## Latest Release Example (b8087)
- **tag_name**: `b8087`
- **target_commitish**: `e2f19b320fa358bb99cee41e2f4606f4ee93cc0c` (full SHA)
- **SHA256**: `7d97703671335ee75428e1ab4f173ff5c09d3ed6c71d85e251bf42b2ff55e280`
- **Short commit**: `e2f19b32` (first 8 characters)

## Update Mapping
| PKGBUILD Variable | Source | Format |
|-------------------|--------|--------|
| `pkgver` | tag_name | Use as-is (e.g., `b8087`) |
| `_build_number` | tag_name | Extract number from tag (e.g., `8087`) |
| `_commit_id` | target_commitish | First 8 characters (e.g., `e2f19b32`) |
| `sha256sums[0]` | tarball download | New SHA256 checksum |

## Script Features
1. **Fetch Latest Release**: Query GitHub API for the latest release
2. **Download & Verify**: Download tarball and calculate SHA256
3. **Backup System**: Create timestamped backup (PKGBUILD.bak.YYYYMMDD)
4. **In-Place Update**: Modify PKGBUILD using sed patterns
5. **Error Handling**: Validate API responses and download success

## API Endpoints
- **Release Info**: `https://api.github.com/repos/ggml-org/llama.cpp/releases/latest`
- **Tarball URL**: `https://github.com/ggml-org/llama.cpp/archive/refs/tags/{tag_name}.tar.gz`

## Required Tools
- `curl` (for API and downloads)
- `jq` (for JSON parsing)
- `sed` (for in-place editing)
- `sha256sum` (for checksum calculation)
- `date` (for timestamp generation)

## Example Output
```bash
$ ./update-pkgbuild.sh

Fetching latest release from ggml-org/llama.cpp...
Latest release: b8087
Commit SHA: e2f19b320fa358bb99cee41e2f4606f4ee93cc0c
SHA256 checksum: 7d97703671335ee75428e1ab4f173ff5c09d3ed6c71d85e251bf42b2ff55e280

Backed up PKGBUILD to PKGBUILD.bak.20260217

Updating PKGBUILD...
  ✓ pkgver updated
  ✓ _build_number updated
  ✓ _commit_id updated
  ✓ sha256sums[0] updated

Ready to commit!
```

## Safety Features
- **Backup First**: Always create backup before modifications
- **Dry Run Option**: Add `-d` flag to preview changes without modifying
- **Verification**: Verify API responses before proceeding
- **Idempotency**: Script can be safely run multiple times
