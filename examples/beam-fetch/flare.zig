//! beam-fetch — proxy a request to a public origin via Beam.
//!
//! Issues a GET to https://api.github.com/zen and returns the upstream
//! body verbatim. Demonstrates outbound HTTP fetch from inside a flare.

const std = @import("std");
const flaron = @import("flaron");

comptime {
    flaron.exportAlloc();
}

var page_buf: [32 * 1024]u8 = undefined;

export fn handle_request() i64 {
    flaron.resetArena();

    var fba = std.heap.FixedBufferAllocator.init(&page_buf);
    const allocator = fba.allocator();

    const resp = flaron.beam.fetch(allocator, "https://api.github.com/zen", .{
        .method = "GET",
        .headers = &.{
            .{ .name = "user-agent", .value = "flaron-zig-example/0.1" },
            .{ .name = "accept", .value = "text/plain" },
        },
    }) catch {
        flaron.response.setStatus(502);
        flaron.response.setBodyStr("upstream fetch failed");
        return flaron.FlareAction.respond.toI64();
    };

    flaron.response.setStatus(resp.status);
    flaron.response.setHeader("content-type", "text/plain; charset=utf-8");
    flaron.response.setBody(resp.body);

    return flaron.FlareAction.respond.toI64();
}
