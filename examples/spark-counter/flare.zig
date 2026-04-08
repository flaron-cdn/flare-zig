//! spark-counter - per-site visit counter using Spark with TTL.
//!
//! Reads `visits`, increments by 1, writes back with a 24-hour TTL,
//! and returns the new count as plain text.

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

    var current: u64 = 0;
    if (flaron.spark.get(allocator, "visits") catch null) |entry| {
        current = std.fmt.parseInt(u64, entry.value, 10) catch 0;
    }

    const next = current + 1;
    var num_buf: [32]u8 = undefined;
    const next_str = std.fmt.bufPrint(&num_buf, "{d}", .{next}) catch "1";
    flaron.spark.set("visits", next_str, 86_400) catch |err| {
        flaron.log.err(@errorName(err));
    };

    var body_buf: [128]u8 = undefined;
    const body = std.fmt.bufPrint(&body_buf, "visits: {d}\n", .{next}) catch "visits: ?\n";

    flaron.response.setStatus(200);
    flaron.response.setHeader("content-type", "text/plain; charset=utf-8");
    flaron.response.setBody(body);

    return flaron.FlareAction.respond.toI64();
}
