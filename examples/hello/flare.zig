//! hello - minimal HTTP echo flare in Zig.
//!
//! Reads the inbound method and URL, returns a plain-text body.
//! Demonstrates the bare minimum a Zig flare needs: alloc export,
//! arena reset, response setters, FlareAction return.

const std = @import("std");
const flaron = @import("flaron");

comptime {
    flaron.exportAlloc();
}

var body_buf: [4096]u8 = undefined;

export fn handle_request() i64 {
    flaron.resetArena();

    var fba = std.heap.FixedBufferAllocator.init(&body_buf);
    const allocator = fba.allocator();

    const method = flaron.request.method(allocator) catch {
        flaron.response.setStatus(500);
        return flaron.FlareAction.respond.toI64();
    };
    const url = flaron.request.url(allocator) catch {
        flaron.response.setStatus(500);
        return flaron.FlareAction.respond.toI64();
    };

    var msg_buf: [1024]u8 = undefined;
    const msg = std.fmt.bufPrint(&msg_buf, "hello from a Zig flare\n{s} {s}\n", .{ method, url }) catch "hello from a Zig flare";

    flaron.response.setStatus(200);
    flaron.response.setHeader("content-type", "text/plain; charset=utf-8");
    flaron.response.setBody(msg);

    return flaron.FlareAction.respond.toI64();
}
