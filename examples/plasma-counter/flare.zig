//! plasma-counter - globally consistent counter via Plasma CRDT.
//!
//! Increments `global_visits` by 1 on every request and returns the
//! aggregate value. Plasma values converge across all edge nodes via
//! gossip, so the count is eventually consistent worldwide.

const std = @import("std");
const flaron = @import("flaron");

comptime {
    flaron.exportAlloc();
}

var page_buf: [8192]u8 = undefined;

export fn handle_request() i64 {
    flaron.resetArena();

    var fba = std.heap.FixedBufferAllocator.init(&page_buf);
    const allocator = fba.allocator();

    const new_val = flaron.plasma.increment(allocator, "global_visits", 1) catch {
        flaron.response.setStatus(500);
        flaron.response.setBodyStr("plasma increment failed");
        return flaron.FlareAction.respond.toI64();
    };

    var body_buf: [128]u8 = undefined;
    const body = std.fmt.bufPrint(&body_buf, "global visits: {d}\n", .{new_val}) catch "global visits: ?\n";

    flaron.response.setStatus(200);
    flaron.response.setHeader("content-type", "text/plain; charset=utf-8");
    flaron.response.setBody(body);

    return flaron.FlareAction.respond.toI64();
}
