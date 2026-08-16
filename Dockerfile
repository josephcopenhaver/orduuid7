# Cross-compile environment: builds all six targets from any host that can
# run a Linux container. clang assembles, lld links every format it needs
# (ELF, PE/COFF, and Mach-O via ld64.lld), llvm-dlltool generates the Windows
# import libraries from src/*.def, and src/libSystem.tbd stands in for the
# Apple SDK.

FROM debian:trixie-slim

RUN apt-get update \
    && apt-get install -y --no-install-recommends clang lld llvm \
    && rm -rf /var/lib/apt/lists/* \
    && ln -s /usr/lib/llvm-*/bin/ld64.lld /usr/local/bin/ld64.lld

ENV IN_BUILD_CONTAINER=1

WORKDIR /work

ENTRYPOINT ["/bin/bash"]
