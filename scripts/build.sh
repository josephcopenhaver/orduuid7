#!/usr/bin/env bash

# Build orduuid7 from the per-target assembly sources in src/.
#
# Always builds inside the Debian container from ./Dockerfile: invoked on a
# host, it constructs that image and re-runs itself in it; the image sets
# IN_BUILD_CONTAINER=1 to mark the inside. Toolchain is plain LLVM: clang
# assembles, ld.lld links ELF and PE, ld64.lld links Mach-O, llvm-dlltool
# generates the Windows import libraries from src/*.def, and src/libSystem.tbd
# stands in for the Apple SDK. The sources are hand-written assembly, so
# there is no codegen to optimize - flags exist to strip and shrink the
# containers.
#
#   linux    freestanding raw syscalls; the source carries its own ELF header
#            and tiny.ld emits the raw memory image. Fully static.
#   windows  console PE importing only kernel32 + bcryptprimitives; no CRT.
#   darwin   libSystem via GOT; ld64.lld ad-hoc signs arm64, so the output
#            runs on a Mac no matter where it was linked.

{

main() {
  set -euo pipefail

  cd "$(dirname "$0")/.."

  if [ "${IN_BUILD_CONTAINER:-}" != 1 ]; then
    docker build -t orduuid7-xbuild . \
      && exec docker run --rm -u "$(id -u):$(id -g)" -v "$PWD:/work" \
        orduuid7-xbuild scripts/build.sh
    return 1
  fi

  rm -rf dist build

  local version='v0.2.0'
  local bin_name=orduuid7
  local obj='build/.obj'

  mkdir -p "$obj" \
    "build/$version/darwin/aarch64-13.0" \
    "build/$version/darwin/x86_64-13.0" \
    "build/$version/linux/x86_64" \
    "build/$version/linux/aarch64" \
    "build/$version/windows/x86_64" \
    "build/$version/windows/aarch64"

  local arch march
  for arch in aarch64 x86_64; do
    march=${arch/aarch64/arm64}
    clang --target="$march-apple-macos13.0" -c \
        -o "$obj/macos-$march.o" "src/macos-$march.s" \
      && ld64.lld -arch "$march" -platform_version macos 13.0 13.0 \
        -dead_strip -x -L src -lSystem \
        -o "build/$version/darwin/$arch-13.0/$bin_name" "$obj/macos-$march.o" \
      || return 1
  done

  for arch in x86_64 aarch64; do
    clang --target="$arch-unknown-linux-gnu" -c \
        -o "$obj/linux-$arch.o" "src/linux-$arch.s" \
      && ld.lld -T src/tiny.ld --build-id=none \
        -o "build/$version/linux/$arch/$bin_name" "$obj/linux-$arch.o" \
      && chmod +x "build/$version/linux/$arch/$bin_name" \
      || return 1
  done

  # -s drops the .buildid section, worth a full 512-byte file block
  local m fmt
  for arch in x86_64 aarch64; do
    if [ "$arch" = x86_64 ]; then m=i386:x86-64 fmt=i386pep; else m=arm64 fmt=arm64pe; fi
    mkdir -p "$obj/lib-$arch"
    llvm-dlltool -m "$m" -d src/kernel32.def -l "$obj/lib-$arch/libkernel32.a" \
      && llvm-dlltool -m "$m" -d src/bcryptprimitives.def -l "$obj/lib-$arch/libbcryptprimitives.a" \
      && clang --target="$arch-windows-gnu" -c \
        -o "$obj/windows-$arch.o" "src/windows-$arch.s" \
      && ld.lld -m "$fmt" --subsystem console --entry mainCRTStartup -s \
        -L "$obj/lib-$arch" -lkernel32 -lbcryptprimitives \
        -o "build/$version/windows/$arch/$bin_name.exe" "$obj/windows-$arch.o" \
      || return 1
  done

  rm -rf "$obj"
  mkdir -p dist

  # construct binary digests
  find build -type f \( -name "$bin_name" -o -name "$bin_name.exe" \) | xargs -n 1 bash -sc 'cd "${1%/*}" ; sha256sum "${1##*/}" > "${1##*/}.sha256"' ''

  # construct binary packages: .zip for windows, .tar.gz for everything else
  find build -type f -name "$bin_name" | sed -E 's/^build\///' | xargs -n 1 bash -sc 'b="${1##*/}" ; d="${1%/*}" ; tar -cf - -C "build/$d" "$b" "$b.sha256" | gzip -9 > "dist/$b-$(sed -E '\''s/\//-/g'\'' <<<"$d").tar.gz"' ''
  find build -type f -name "$bin_name.exe" | sed -E 's/^build\///' | xargs -n 1 bash -sc 'b="${1##*/}" ; d="${1%/*}" ; zip -9 -X -j -q "dist/${b%.exe}-$(sed -E '\''s/\//-/g'\'' <<<"$d").zip" "build/$d/$b" "build/$d/$b.sha256"' ''

  # construct binary package digests
  find dist -type f \( -name '*.tar.gz' -o -name '*.zip' \) | xargs -n 1 bash -sc 'fname="${1##*/}" ; cd dist ; sha256sum "$fname" > "$fname.sha256"' ''
}

(main "$@") && exit 0 || exit $?

}
