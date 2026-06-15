#!/usr/bin/env bash

(
main() {
  set -euo pipefail

  rm -rf dist build
  mkdir -p build

  local version='v0.1.0'
  local bin_name=orduuid7
  local build_op='build-exe -O ReleaseSmall -fstrip -fsingle-threaded -fno-unwind-tables -fomit-frame-pointer main.zig'
  local build_mac_op='-dead_strip -dead_strip_dylibs'

  mkdir -p "build/$version/darwin/aarch64-13.0"
  mkdir -p "build/$version/darwin/x86_64-13.0"
  mkdir -p "build/$version/linux/x86_64-musl"
  mkdir -p "build/$version/linux/aarch64-musl"

  zig $(printf %s "$build_op") $(printf %s "$build_mac_op") -target aarch64-macos.13.0.0 -femit-bin="build/$version/darwin/aarch64-13.0/$bin_name" || true
  zig $(printf %s "$build_op") $(printf %s "$build_mac_op") -target x86_64-macos.13.0.0 -femit-bin="build/$version/darwin/x86_64-13.0/$bin_name" || true
  zig $(printf %s "$build_op") -target x86_64-linux-musl -femit-bin="build/$version/linux/x86_64-musl/$bin_name"
  zig $(printf %s "$build_op") -target aarch64-linux-musl -femit-bin="build/$version/linux/aarch64-musl/$bin_name"

  mkdir -p dist

  # construct binary digests
  find build -type f -name "$bin_name" | sed -E 's/\/[^\/]+$//' | xargs -n 1 bash -sc 'cd "$2" ; sha256sum "$1" > "$1.sha256"' '' "$bin_name"

  # construct binary packages
  find build -type f -name "$bin_name" | sed -E 's/^build\/// ; s/\/[^\/]+$//' | xargs -n 1 bash -sc 'tar -cf - -C "build/$2" "$1" "$1.sha256" | gzip -9 > "dist/$1-$(sed -E '\''s/\//-/g'\'' <<<"$2").tar.gz"' '' "$bin_name"

  # construct binary package digests
  find build -type f -name "$bin_name" | sed -E 's/^build\/// ; s/\/[^\/]+$//' | xargs -n 1 bash -sc 'fname="$1-$(sed -E '\''s/\//-/g'\'' <<<"$2").tar.gz" ; cd dist ; sha256sum "$fname" > "$fname.sha256"' '' "$bin_name"
}

main "$@"
)
