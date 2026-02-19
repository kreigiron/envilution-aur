# PKGBUILD Updater

Automated script to update the Arch Linux PKGBUILD for `llama.cpp-cuda` with the latest llama.cpp release.

## Overview

This script automates the process of updating the `PKGBUILD` file for the `llama.cpp-cuda` AUR package by:

- Fetching the latest release from ggml-org/llama.cpp
- Calculating the SHA256 checksum of the downloaded tarball
- Backing up the existing PKGBUILD
- Updating version numbers and checksums in-place

## Requirements

- Bash (version 4.0+)
- curl
- jq
- sha256sum (usually available with coreutils)

## Installation

1. Place `update-pkgbuild.sh` in the same directory as `PKGBUILD`:
```bash
cp update-pkgbuild.sh /path/to/aur/llama.cpp-cuda/
```

2. Make the script executable:
```bash
chmod +x update-pkgbuild.sh
```

## Usage

### Basic Usage

Update the PKGBUILD with the latest release:
```bash
./update-pkgbuild.sh
```

### Preview Changes

Review what changes will be made without modifying the file:
```bash
./update-pkgbuild.sh --dry-run
```

### Show Help

Display usage information and options:
```bash
./update-pkgbuild.sh --help
```

## Options

| Option | Description |
|--------|-------------|
| `-d, --dry-run` | Preview changes without modifying the PKGBUILD file |
| `-h, --help` | Display help message and exit |

## How It Works

1. **Fetch Release Information**: Queries GitHub releases API for ggml-org/llama.cpp
2. **Download Tarball**: Downloads the latest llama.cpp tarball
3. **Calculate SHA256**: Computes the SHA256 checksum of the tarball
4. **Backup PKGBUILD**: Creates a backup with timestamp (e.g., `PKGBUILD.bak.20260217.001`)
5. **Update PKGBUILD**: Modifies the file in-place with new values:
   - `pkgver` - Latest release tag (e.g., `b8087`)
   - `_build_number` - Build number extracted from tag
   - `_commit_id` - First 8 characters of commit SHA
   - `sha256sums[0]` - New tarball checksum

### Backup Naming Convention

- First backup: `PKGBUILD.bak.YYYYMMDD`
- Subsequent backups: `PKGBUILD.bak.YYYYMMDD.NNN`
  - `NNN` is a 3-digit incremental number (001, 002, 003, ...)
  - Prevents overwriting existing backups on the same day

## Example Output

### Normal Run
```
[INFO] Starting PKGBUILD update automation...
[INFO] Fetching latest release from ggml-org/llama.cpp...
[INFO] Latest release: b8087
[INFO] Commit SHA: e2f19b320fa358bb99cee41e2f4606f4ee93cc0c
[INFO] Downloading tarball from https://github.com/...
[INFO] SHA256 checksum: 7d97703671335ee75428e1ab4f173ff5c09d3ed6c71d85e251bf42b2ff55e280
[INFO] Backing up PKGBUILD to PKGBUILD.bak.20260217
[INFO] Updating PKGBUILD...
[INFO]   ✓ pkgver updated
[INFO]   ✓ _build_number updated
[INFO]   ✓ _commit_id updated
[INFO]   ✓ sha256sums[0] updated
[INFO] 
[INFO] Update complete!
[INFO] Review changes and commit: git add PKGBUILD && git commit -m 'Update to b8087'
```

### Dry-Run Mode
```
[INFO] Starting PKGBUILD update automation...
[INFO] Fetching latest release from ggml-org/llama.cpp...
[INFO] Latest release: b8087
[INFO] Commit SHA: e2f19b320fa358bb99cee41e2f4606f4ee93cc0c
[INFO] Downloading tarball from https://github.com/...
[INFO] SHA256 checksum: 7d97703671335ee75428e1ab4f173ff5c09d3ed6c71d85e251bf42b2ff55e280
[INFO] [DRY RUN] Would update:
[INFO]   pkgver=b8087
[INFO]   _build_number=8087
[INFO]   _commit_id=e2f19b32
[INFO]   sha256sums[0]='7d97703671335ee75428e1ab4f173ff5c09d3ed6c71d85e251bf42b2ff55e280'
[INFO] 
[INFO] Update complete!
```

## Troubleshooting

### Error: "jq is required but not installed"
Install jq:
```bash
pacman -S jq
```

### Error: "Failed to fetch release information"
- Check internet connectivity
- Verify ggml-org/llama.cpp repository exists on GitHub
- Check if GitHub API is accessible

### Error: "Backup file already exists"
The script now handles multiple daily backups automatically. If you see this error:
- Remove old backup files: `rm PKGBUILD.bak.YYYYMMDD.*`
- Or run the script again (it will create incremental backups)

### Unexpected PKGBUILD changes
- Always use `--dry-run` first to preview changes
- Review the backup file before committing

## Integration

After running the script successfully, you can commit the changes:

```bash
git add PKGBUILD
git commit -m "Update to $(grep pkgver= PKGBUILD | cut -d= -f2)"
git push origin main
```

## Notes

- The script updates the PKGBUILD in-place
- Backups are created with timestamps for easy rollback
- Incremental backup numbers prevent accidental overwrites
- SHA256 checksums are calculated automatically
- The script uses stderr for logging to avoid interfering with output parsing
