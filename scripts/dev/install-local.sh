#!/usr/bin/env bash
set -Eeuo pipefail

usage() {
  cat >&2 <<'EOF_USAGE'
Usage: scripts/dev/install-local.sh [options]

Install the Soon.app bundle already built in dist/ and launch it.

Options:
  --dist-dir <dir>  Distribution directory. Default: dist
  --app-dir <dir>   App installation directory. Default: ~/Applications
  --no-launch       Install without launching Soon.
EOF_USAGE
}

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
project_root="$(cd -- "$script_dir/../.." && pwd -P)"

dist_dir="${DIST_DIR:-dist}"
app_dir="${LOCAL_APP_DIR:-$HOME/Applications}"
launch_app=true

while [ "$#" -gt 0 ]; do
  case "$1" in
  --dist-dir)
    dist_dir="${2:?missing value for --dist-dir}"
    shift 2
    ;;
  --app-dir)
    app_dir="${2:?missing value for --app-dir}"
    shift 2
    ;;
  --no-launch)
    launch_app=false
    shift
    ;;
  -h | --help)
    usage
    exit 0
    ;;
  *)
    echo "Unknown argument: $1" >&2
    usage
    exit 2
    ;;
  esac
done

if [ "$(uname -s)" != "Darwin" ]; then
  echo "Local installation is supported only on macOS." >&2
  exit 1
fi

case "$dist_dir" in
/*) ;;
*) dist_dir="$project_root/$dist_dir" ;;
esac

app_source="${dist_dir%/}/Soon.app"
app_destination="${app_dir%/}/Soon.app"

if [ ! -d "$app_source" ]; then
  echo "Missing Soon app bundle: $app_source" >&2
  exit 1
fi

for command_name in ditto open xattr; do
  if ! command -v "$command_name" >/dev/null 2>&1; then
    echo "Required command not found: $command_name" >&2
    exit 1
  fi
done

if command -v brew >/dev/null 2>&1; then
  brew services stop soon >/dev/null 2>&1 || true
fi
pkill -x Soon >/dev/null 2>&1 || true

mkdir -p "$app_dir"
stage="${app_dir%/}/.Soon.app.local-install.$$"
rm -rf "$stage"
ditto "$app_source" "$stage"
rm -rf "$app_destination"
mv "$stage" "$app_destination"

xattr -dr com.apple.quarantine "$app_destination" >/dev/null 2>&1 || true

installed_version="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$app_destination/Contents/Info.plist")"
echo "Installed Soon $installed_version"
echo "App: $app_destination"

if [ "$launch_app" = true ]; then
  echo "Launching $app_destination"
  open "$app_destination"
fi
