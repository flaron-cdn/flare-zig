//! edge-ops - exercise edge operations: hash, base64, ULID, timestamp.
//!
//! Computes SHA-256 of "flaron", base64-encodes the request URL,
//! generates a fresh ULID, and reads the current edge time. Returns
//! all four as a plain-text report.

const std = @import("std");
const flaron = @import("flaron");

comptime {
    flaron.exportAlloc();
}

var page_buf: [16 * 1024]u8 = undefined;

export fn handle_request() i64 {
    flaron.resetArena();

    var fba = std.heap.FixedBufferAllocator.init(&page_buf);
    const allocator = fba.allocator();

    const sha = flaron.crypto.hash(allocator, "sha256", "flaron") catch "?";
    const url = flaron.request.url(allocator) catch "?";
    const url_b64 = flaron.encoding.base64Encode(allocator, url) catch "?";
    const id = flaron.id.ulid(allocator) catch "?";
    const now = flaron.time.now(allocator, flaron.time.Format.rfc3339) catch "?";

    var body_buf: [4096]u8 = undefined;
    const body = std.fmt.bufPrint(&body_buf,
        \\sha256(flaron) = {s}
        \\base64(url)    = {s}
        \\ulid           = {s}
        \\edge time      = {s}
        \\
    , .{ sha, url_b64, id, now }) catch "edge-ops: format failed";

    flaron.response.setStatus(200);
    flaron.response.setHeader("content-type", "text/plain; charset=utf-8");
    flaron.response.setBody(body);

    return flaron.FlareAction.respond.toI64();
}
