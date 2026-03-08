#!/usr/bin/env bash
# Scrape TP-Link support page for the latest Omada Linux tar.gz + release notes PDF.
# If $1 is provided, use it as the download URL instead of scraping for it,
# but still scrape the support page to find the matching release notes PDF.
# Outputs to $GITHUB_OUTPUT: version, download_url, release_notes_url
set -euo pipefail

url_encode() {
  python3 -c "
import urllib.parse, sys
u = sys.argv[1]
p = urllib.parse.urlsplit(u)
print(urllib.parse.urlunsplit(p._replace(path=urllib.parse.quote(p.path, safe='/:@!\$&\'()*+,;='))))
" "$1"
}

SUPPORT_URL="https://support.omadanetworks.com/us/download/software/omada-controller/"

html=$(curl -fsSL "$SUPPORT_URL")

if [[ -n "${1:-}" ]]; then
  download_url=$(url_encode "$1")
else
  raw_url=$(echo "$html" | grep -oE 'href="https://static\.tp-link\.com/upload/software/[^"]+_linux_x64_[^"]+\.tar\.gz"' | head -1 | sed 's/href="//; s/"$//')
  if [[ -z "$raw_url" ]]; then
    echo "ERROR: could not find linux tar.gz download URL" >&2
    exit 1
  fi
  download_url=$(url_encode "$raw_url")
fi

# Extract version from filename e.g. Omada_SDN_Controller_v5.15.20.20_linux_x64_...
version=$(echo "$download_url" | grep -oE 'v[0-9]+(\.[0-9]+)+' | head -1 | tr -d 'v')
if [[ -z "$version" ]]; then
  echo "ERROR: could not extract version from URL: $download_url" >&2
  exit 1
fi

# Find Linux-specific PDF in the same date directory as the tar.gz
date_dir=$(echo "$download_url" | grep -oE 'upload/software/[0-9]+/[0-9]+/[0-9]+/')
release_notes_url=$(echo "$html" | grep -oE "href=\"https://static\\.tp-link\\.com/${date_dir}[^\"]+[Ll]inux[^\"]+\\.pdf\"" | head -1 | sed 's/href="//; s/"$//; s/&amp;/\&/g; s/ /%20/g')
# Fall back to any PDF in the same directory
if [[ -z "$release_notes_url" ]]; then
  release_notes_url=$(echo "$html" | grep -oE "href=\"https://static\\.tp-link\\.com/${date_dir}[^\"]+\\.pdf\"" | head -1 | sed 's/href="//; s/"$//; s/&amp;/\&/g; s/ /%20/g')
fi

echo "version=$version" >> "$GITHUB_OUTPUT"
echo "download_url=$download_url" >> "$GITHUB_OUTPUT"
echo "release_notes_url=${release_notes_url:-}" >> "$GITHUB_OUTPUT"

echo "Version: $version"
echo "Download URL: $download_url"
echo "Release notes URL: ${release_notes_url:-N/A}"
