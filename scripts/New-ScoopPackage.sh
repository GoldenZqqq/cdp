#!/usr/bin/env bash

set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
version="${1:-$(sed -n "s/^ModuleVersion = '\([^']*\)'$/\1/p" "$repo_root/cdp.psd1" | head -n 1)}"
output_path="${2:-$repo_root/cdp-$version.tar.gz}"
[[ "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || { echo "invalid version: $version" >&2; exit 1; }
staging_root="$(mktemp -d "${TMPDIR:-/tmp}/cdp-scoop-package.XXXXXX")"
package_root="$staging_root/cdp-$version"
trap 'rm -rf "$staging_root"' EXIT

mkdir -p "$package_root/scripts" "$package_root/src"
cp "$repo_root/cdp.psd1" "$repo_root/Install.ps1" "$package_root/"
cp "$repo_root/scripts/Cdp.Installation.ps1" "$package_root/scripts/"
cp -R "$repo_root/src/." "$package_root/src/"

tar --sort=name \
    --mtime='UTC 2000-01-01' \
    --owner=0 --group=0 --numeric-owner \
    -czf "$output_path" \
    -C "$staging_root" "cdp-$version"

echo "$output_path"
