#!/usr/bin/env bash
set -euo pipefail

TARBALL="${1:?Usage: $0 <tarball> <output-dir>}"
OUTPUT_DIR="${2:?Usage: $0 <tarball> <output-dir>}"

WORK_DIR=$(mktemp -d)
trap 'rm -rf "$WORK_DIR"' EXIT

tar -xzf "$TARBALL" -C "$WORK_DIR"

# Find lib/ directory inside the extracted tree
lib_dir=$(find "$WORK_DIR" -type d -name lib | head -1)
if [[ -z "$lib_dir" ]]; then
  echo "ERROR: no lib/ directory found in tarball" >&2
  exit 1
fi

mkdir -p "$OUTPUT_DIR"
find "$lib_dir" -maxdepth 1 -name "*.jar" -exec cp {} "$OUTPUT_DIR/" \;

echo "Extracted JARs to $OUTPUT_DIR:"
ls "$OUTPUT_DIR/"
