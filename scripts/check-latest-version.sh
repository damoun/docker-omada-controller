#!/usr/bin/env bash
set -euo pipefail

SUPPORT_URL="https://support.omadanetworks.com/us/download/software/omada-controller/"

html=$(curl -fsSL "$SUPPORT_URL")

download_url=$(echo "$html" | grep -oE 'https://static\.tp-link\.com/upload/software/[^"]+_linux_x64_[^"]+\.tar\.gz' | head -1)
if [[ -z "$download_url" ]]; then
  echo "ERROR: could not find linux tar.gz download URL" >&2
  exit 1
fi

release_notes_url=$(echo "$html" | grep -oE 'href="https://static\.tp-link\.com/upload/software/[^"]+\.pdf"' | head -1 | sed 's/href="//; s/"$//; s/&amp;/\&/g; s/ /%20/g')

# Extract version from filename e.g. Omada_Network_Application_v6.1.0.19_linux_x64_...
version=$(echo "$download_url" | grep -oE 'v[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+' | head -1 | tr -d 'v')
if [[ -z "$version" ]]; then
  echo "ERROR: could not extract version from URL: $download_url" >&2
  exit 1
fi

echo "version=$version" >> "$GITHUB_OUTPUT"
echo "download_url=$download_url" >> "$GITHUB_OUTPUT"
echo "release_notes_url=${release_notes_url:-}" >> "$GITHUB_OUTPUT"

echo "Latest version: $version"
echo "Download URL: $download_url"
echo "Release notes URL: ${release_notes_url:-N/A}"
