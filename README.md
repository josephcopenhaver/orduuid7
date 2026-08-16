# orduuid7

Prints one time-ordered 128-bit id as 32 lowercase hex characters plus a newline.

```
$ orduuid7
01a008e91dd35c0c27bc097aa3beff67
```

## What the id is

A standard [UUIDv7 (RFC 9562)](https://www.rfc-editor.org/rfc/rfc9562#name-uuid-version-7)
— 48-bit big-endian Unix millisecond timestamp plus 74 random bits — except
the bits not related to uniqueness (the constant version and variant fields)
are shifted to the least significant bits, and the result is hex encoded
without dashes. Same spirit as
[ord-uuid-rs](https://github.com/josephcopenhaver/ord-uuid-rs) v7

```
standard UUIDv7:
| unix_ts_ms (48) | ver=0111 (4) | rand_a (12) | var=10 (2) | rand_b (62) |

orduuid7:
| unix_ts_ms (48) |                rand (74)                | var=10 (2) | ver=0111 (4) |
                                                            '------ tag = 0x27 --------'
```

Both layouts carry exactly the same information: a 48-bit timestamp, 74
random bits, and 6 constant bits. The transformation is a pure bit
permutation, so an orduuid7 can be mechanically converted back into a
byte-standard UUIDv7 and vice versa. The last byte is
`(rand & 0xc0) | 0x27`: two random bits, then the variant and version
constants packed at the very end.

## Rationale

The id is meant to be sorted — as raw bytes in a binary index or as a hex
string in anything text-shaped — and both orderings are identical here and
equal to creation order (millisecond precision, random within a
millisecond).

A standard UUIDv7 already starts with its timestamp, but it interrupts the
significant bits twice: the constant `0111` version nibble sits immediately
after the timestamp and the constant `10` variant bits sit in the middle of
the random field. Those 6 bits never distinguish two ids, yet every
comparison walks through them, and they split the entropy into two
non-adjacent fragments. Moving them to the least significant end makes the
id maximally discriminating from the front — timestamp, then uninterrupted
entropy — with the constants placed where they can never matter until
everything else ties. Dropping the dashes makes the hex form compact and
keeps its lexical order identical to the binary order.

The low 6 bits of every id are always `0x27` (`10` `0111`), which doubles as
a cheap validity tag.

## Entropy and time

The 74 random bits always come from the operating system's CSPRNG — there is
no userspace PRNG and no weaker fallback path:

| OS      | Random source                                                          | Clock source                          |
| ------- | ---------------------------------------------------------------------- | ------------------------------------- |
| linux   | `getrandom` syscall (kernel CSPRNG, the `/dev/urandom` pool)           | `clock_gettime(CLOCK_REALTIME)` syscall |
| darwin  | `getentropy` (kernel CSPRNG, via libSystem)                            | `clock_gettime(CLOCK_REALTIME)` (libSystem) |
| windows | `ProcessPrng` (kernel-seeded CSPRNG behind `BCryptGenRandom`, no bcrypt.dll wrapper) | `GetSystemTimeAsFileTime`             |

The timestamp depends on those clock calls reading the system's wall clock
(`CLOCK_REALTIME` / system time), so ids are only as time-ordered as the
clock is correct: a clock stepped backwards (manual change, aggressive NTP
correction) produces ids that sort into the past accordingly. Uniqueness
does not depend on the clock — the 74 CSPRNG bits carry it alone
(collision odds ~1 in 2⁷⁴ even inside a single millisecond).

## Usage

Run it; read one id from stdout. Exit code 0 means the full 33 bytes were
written; anything else means the write failed and the output must not be
trusted. No arguments, no environment, no configuration.

## Build

```bash
./scripts/build.sh
```

Builds happen inside a Debian container (see `Dockerfile`), so the only host
requirement is Docker; every target cross-compiles from any host. The
implementation is hand-written assembly per target (`src/*.s`) assembled by
clang and linked by lld; `src/*.def` and `src/libSystem.tbd` replace the
Windows and Apple SDKs. Outputs land in `build/<version>/` with tarballs and
sha256 digests in `dist/`.

| Target          | Size (bytes) | How static                                        |
| --------------- | -----------: | ------------------------------------------------- |
| linux/x86_64    |          306 | fully — raw syscalls, no libc, runs `from scratch` |
| linux/aarch64   |          344 | fully — raw syscalls, no libc, runs `from scratch` |
| windows/x86_64  |        2,048 | as static as Windows allows — imports only kernel32 + bcryptprimitives, no CRT |
| windows/aarch64 |        2,048 | as static as Windows allows — imports only kernel32 + bcryptprimitives, no CRT |
| darwin/x86_64   |        8,536 | as static as macOS allows — links only libSystem, no CRT |
| darwin/aarch64  |       33,536 | as static as macOS allows — links only libSystem, ad-hoc signed |

The sizes are format floors, not code: the Linux files are a hand-written
ELF header plus ~200 bytes of instructions, and the Windows and macOS
numbers are file-alignment and page-alignment minimums for any executable
in those formats that imports a symbol.

## History

The original implementation was Zig (`original.main.zig.txt`, kept for
reference); it was ported to per-target assembly to remove as much bloat as possible.
