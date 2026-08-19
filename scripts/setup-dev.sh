#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-or-later
# Fetches development dependencies that are not committed to the repository.
set -euo pipefail

GUT_VERSION="v9.6.1"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

if [ -d "$ROOT/addons/gut" ]; then
    echo "GUT already present at addons/gut"
    exit 0
fi

echo "Fetching GUT $GUT_VERSION..."
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

curl -fsSL "https://github.com/bitwes/Gut/archive/refs/tags/${GUT_VERSION}.tar.gz" \
    | tar -xz -C "$tmp"

mkdir -p "$ROOT/addons"
cp -r "$tmp/Gut-${GUT_VERSION#v}/addons/gut" "$ROOT/addons/"

echo "Installed GUT $GUT_VERSION to addons/gut"
