#!/usr/bin/env bash

(
main() {
  set -euo pipefail

  rm -rf dist build
  mkdir -p build

  local version='v0.1.1'
  local bin_name=orduuid7
  local build_op='build-exe -O ReleaseSmall -fstrip -fsingle-threaded -fno-unwind-tables -fomit-frame-pointer main.zig'
  local build_mac_op='-dead_strip -dead_strip_dylibs'

  mkdir -p "build/$version/darwin/aarch64-13.0"
  mkdir -p "build/$version/darwin/x86_64-13.0"
  mkdir -p "build/$version/linux/x86_64-musl"
  mkdir -p "build/$version/linux/aarch64-musl"
  mkdir -p "build/$version/windows/x86_64"
  mkdir -p "build/$version/windows/aarch64"

  zig $(printf %s "$build_op") $(printf %s "$build_mac_op") -target aarch64-macos.13.0.0 -femit-bin="build/$version/darwin/aarch64-13.0/$bin_name" || true
  zig $(printf %s "$build_op") $(printf %s "$build_mac_op") -target x86_64-macos.13.0.0 -femit-bin="build/$version/darwin/x86_64-13.0/$bin_name" || true
  zig $(printf %s "$build_op") -target x86_64-linux-musl -femit-bin="build/$version/linux/x86_64-musl/$bin_name"
  zig $(printf %s "$build_op") -target aarch64-linux-musl -femit-bin="build/$version/linux/aarch64-musl/$bin_name"
  zig $(printf %s "$build_op") --subsystem console -target x86_64-windows -femit-bin="build/$version/windows/x86_64/$bin_name.exe"
  zig $(printf %s "$build_op") --subsystem console -target aarch64-windows -femit-bin="build/$version/windows/aarch64/$bin_name.exe"

  mkdir -p dist

  # construct binary digests
  find build -type f \( -name "$bin_name" -o -name "$bin_name.exe" \) | xargs -n 1 bash -sc 'cd "${1%/*}" ; sha256sum "${1##*/}" > "${1##*/}.sha256"' ''

  # construct binary packages
  find build -type f \( -name "$bin_name" -o -name "$bin_name.exe" \) | sed -E 's/^build\///' | xargs -n 1 bash -sc 'b="${1##*/}" ; d="${1%/*}" ; tar -cf - -C "build/$d" "$b" "$b.sha256" | gzip -9 > "dist/${b%.exe}-$(sed -E '\''s/\//-/g'\'' <<<"$d").tar.gz"' ''

  # construct binary package digests
  find dist -type f -name '*.tar.gz' | xargs -n 1 bash -sc 'fname="${1##*/}" ; cd dist ; sha256sum "$fname" > "$fname.sha256"' ''
}

main "$@"
)
