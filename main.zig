const std = @import("std");

pub const panic = std.debug.FullPanic(struct {
    fn h(_: []const u8, _: ?usize) noreturn {
        @trap();
    }
}.h);

const hex = "0123456789abcdef";

fn id(io: std.Io) ![16]u8 {
    var v: [16]u8 = undefined;

    const now = std.Io.Clock.now(.real, io);
    const ms: u64 = @intCast(@divFloor(now.nanoseconds, std.time.ns_per_ms));

    v[0] = @truncate(ms >> 40);
    v[1] = @truncate(ms >> 32);
    v[2] = @truncate(ms >> 24);
    v[3] = @truncate(ms >> 16);
    v[4] = @truncate(ms >> 8);
    v[5] = @truncate(ms);

    try std.Io.randomSecure(io, v[6..]);

    v[15] = (v[15] & 0xc0) | 0x27;

    return v;
}

pub fn main(init: std.process.Init) !void {
    const io = init.io;
    const x = try id(io);

    var buf: [33]u8 = undefined;

    var i: usize = 0;
    while (i < 16) : (i+=1) {
        const dst = i * 2;
        const v = x[i];

        buf[dst] = hex[v >> 4];
        buf[dst + 1] = hex[v & 0x0f];
    }

    buf[32] = '\n';

    try std.Io.File.stdout().writeStreamingAll(io, &buf);
}
