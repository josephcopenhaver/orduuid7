const std = @import("std");

pub const panic = std.debug.FullPanic(struct {
    fn h(_: []const u8, _: ?usize) noreturn {
        @trap();
    }
}.h);

const hex = "0123456789abcdef";

fn id_buf(io: std.Io) ![33]u8 {
    var v: [33]u8 = undefined;

    var dst: u8 = 0;

    // load time as hex into buf v
    {
        const now = std.Io.Clock.now(.real, io);
        const ms: u64 = @intCast(@divFloor(now.nanoseconds, std.time.ns_per_ms));

        var bshift: u6 = 40;
        while (true) {
            const b: u8 = @truncate(ms >> bshift);

            v[dst] = hex[b >> 4];
            dst += 1;
            v[dst] = hex[b & 0x0f];
            dst += 1;

            if (bshift < 8) {
                break;
            }

            bshift -= 8;
        }
    }

    var src: u8 = 22;
    try std.Io.randomSecure(io, v[src..32]);

    while (true) {
        const b = v[src];
        src += 1;

        v[dst] = hex[b >> 4];
        dst += 1;
        v[dst] = hex[b & 0x0f];
        dst += 1;

        if (src >= 31) {
            break;
        }
    }

    v[30] = hex[(v[src] & 0x0c) | 0x02];
    v[31] = '7';
    v[32] = '\n';

    return v;
}

pub fn main(init: std.process.Init) !void {
    const io = init.io;
    const buf = try id_buf(io);

    try std.Io.File.stdout().writeStreamingAll(io, &buf);
}
