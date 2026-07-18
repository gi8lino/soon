#!/usr/bin/env bash
set -euo pipefail

version_prefix="${VERSION_PREFIX:-v}"

if [ "${1:-}" = "--version-prefix" ]; then
  if [ "$#" -lt 2 ]; then
    echo "Missing value for --version-prefix" >&2
    exit 2
  fi
  version_prefix=$2
  shift 2
fi

if [ "$#" -ne 0 ]; then
  echo "Usage: $0 [--version-prefix PREFIX]" >&2
  exit 2
fi

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
project_root="$(cd -- "$script_dir/../.." && pwd -P)"
cd "$project_root"

head_commit="$(git rev-parse --verify HEAD)"
short_commit="$(git rev-parse --short=8 "$head_commit")"
latest_tag="$({
  git tag --merged "$head_commit" --list "${version_prefix}*" --sort=-v:refname
} | sed -n '1p')"

if [ -n "$latest_tag" ]; then
  base_version="${latest_tag#"$version_prefix"}"
else
  base_version="0.0.0"
fi

version="${base_version}-dev.${short_commit}"
if ! git diff --quiet HEAD -- . || [ -n "$(git ls-files --others --exclude-standard)" ]; then
  version="${version}-dirty"
fi

printf '%s\n' "$version"
