#!/usr/bin/env bash
set -euo pipefail

TARBALL="${1:?Usage: $0 <tarball> <output-dir>}"
OUTPUT_DIR="${2:?Usage: $0 <tarball> <output-dir>}"

WORK_DIR=$(mktemp -d)
trap 'rm -rf "$WORK_DIR"' EXIT

tar -xzf "$TARBALL" -C "$WORK_DIR"

# Find the root of the extracted package
root_dir=$(find "$WORK_DIR" -mindepth 1 -maxdepth 1 -type d | head -1)
if [[ -z "$root_dir" ]]; then
  echo "ERROR: could not find extracted directory in tarball" >&2
  exit 1
fi

# Copy JARs
lib_dir="$root_dir/lib"
if [[ ! -d "$lib_dir" ]]; then
  echo "ERROR: no lib/ directory found in tarball" >&2
  exit 1
fi
mkdir -p "$OUTPUT_DIR"
find "$lib_dir" -maxdepth 1 -name "*.jar" -exec cp {} "$OUTPUT_DIR/" \;
echo "Extracted $(ls "$OUTPUT_DIR/"*.jar 2>/dev/null | wc -l) JARs to $OUTPUT_DIR"

# Sync properties/, data/ back into the repo working directory
for dir in properties data; do
  src="$root_dir/$dir"
  if [[ -d "$src" ]]; then
    rsync -a --delete "$src/" "$dir/"
    echo "Synced $dir/"
  fi
done
