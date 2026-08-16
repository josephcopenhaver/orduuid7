const builtin = @import("builtin");
const std = @import("std");

pub const panic = std.debug.FullPanic(struct {
    fn h(_: []const u8, _: ?usize) noreturn {
        @trap();
    }
}.h);

const TAG: u8 = 0x27;
const hex = "0123456789abcdef";

// Declaring `_start` (and `WinMainCRTStartup` for Windows) in the root file
// stops std.start from exporting its own entry point; the real per-OS entry
// symbol is exported below.
pub const _start = {};
pub const WinMainCRTStartup = {};

comptime {
    switch (builtin.os.tag) {
        .linux => @export(&linuxStart, .{ .name = "_start" }),
        .macos => @export(&macosMain, .{ .name = "main" }),
        .windows => @export(&windowsStart, .{ .name = "wWinMainCRTStartup" }),
        else => @compileError("unsupported target OS"),
    }
}

// raw[6..16] must already hold 10 random bytes.
fn render(ms: u64, raw: *[16]u8) [33]u8 {
    inline for (0..6) |i| raw[i] = @truncate(ms >> (8 * (5 - i)));
    raw[15] = (raw[15] & 0xc0) | TAG;

    var out: [33]u8 = undefined;
    for (raw, 0..) |b, i| {
        out[2 * i] = hex[b >> 4];
        out[2 * i + 1] = hex[b & 15];
    }
    out[32] = '\n';
    return out;
}

fn linuxStart() callconv(.c) noreturn {
    const linux = std.os.linux;

    var ts: [2]usize = undefined; // timespec: { sec, nsec }
    _ = linux.syscall2(.clock_gettime, 0, @intFromPtr(&ts)); // CLOCK_REALTIME

    var raw: [16]u8 = undefined;
    _ = linux.syscall3(.getrandom, @intFromPtr(&raw) + 6, 10, 0);

    const out = render(ts[0] * 1000 + ts[1] / 1_000_000, &raw);
    const wrote = linux.syscall3(.write, 1, @intFromPtr(&out), out.len);
    _ = linux.syscall1(.exit_group, @intFromBool(wrote != out.len));
    unreachable;
}

extern "c" fn clock_gettime(clock_id: c_int, tp: *[2]u64) c_int;
extern "c" fn getentropy(buf: [*]u8, len: usize) c_int;
extern "c" fn write(fd: c_int, buf: [*]const u8, len: usize) isize;

extern "kernel32" fn GetSystemTimeAsFileTime(ft: *u64) callconv(.winapi) void;
extern "kernel32" fn GetStdHandle(id: u32) callconv(.winapi) ?*anyopaque;
extern "kernel32" fn WriteFile(h: ?*anyopaque, buf: [*]const u8, len: u32, written: *u32, overlapped: ?*anyopaque) callconv(.winapi) i32;
extern "kernel32" fn ExitProcess(code: u32) callconv(.winapi) noreturn;
extern "bcryptprimitives" fn ProcessPrng(buf: [*]u8, len: usize) callconv(.winapi) i32;

fn windowsStart() callconv(.winapi) noreturn {
    var ft: u64 = undefined; // FILETIME: 100ns ticks since 1601-01-01
    GetSystemTimeAsFileTime(&ft);

    var raw: [16]u8 = undefined;
    _ = ProcessPrng(raw[6..], 10);

    const out = render((ft - 116444736000000000) / 10000, &raw);
    // WriteFile zeroes n before any work, so on failure n != out.len
    var n: u32 = undefined;
    _ = WriteFile(GetStdHandle(0xFFFFFFF5), &out, out.len, &n, null); // STD_OUTPUT_HANDLE
    ExitProcess(@intFromBool(n != out.len));
}

fn macosMain() callconv(.c) c_int {
    var ts: [2]u64 = undefined; // timespec: { sec, nsec }
    _ = clock_gettime(0, &ts); // CLOCK_REALTIME

    var raw: [16]u8 = undefined;
    _ = getentropy(raw[6..], 10);

    const out = render(ts[0] * 1000 + ts[1] / 1_000_000, &raw);
    return @intFromBool(write(1, &out, out.len) != out.len);
}
