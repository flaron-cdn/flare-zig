//! Edge-side timestamps in a variety of formats.
//!
//! All timestamps are produced by the host so they reflect the wall clock of
//! the edge node serving the request, not the (non-existent) Wasm clock.

const std = @import("std");
const env = @import("env.zig");

pub const Format = struct {
    pub const unix = "unix";
    pub const millis = "ms";
    pub const nanos = "ns";
    pub const rfc3339 = "rfc3339";
    pub const http = "http";
    pub const iso8601 = "iso8601";
};

/// Get the current edge time formatted according to `fmt`.
///
/// `fmt` must be one of the constants in [`Format`]. Unknown formats fall
/// back to RFC 3339 host-side. Returns an empty slice only if the host
/// returned no result, which should never happen in production.
pub fn now(allocator: std.mem.Allocator, fmt: []const u8) ![]u8 {
    var buf: [128]u8 = undefined;
    const args = try std.fmt.bufPrint(&buf, "{{\"format\":\"{s}\"}}", .{fmt});
    if (try env.timestampFmt(allocator, args)) |bytes| return bytes;
    return allocator.alloc(u8, 0);
}

/// Convenience: current time as Unix milliseconds. Returns `0` if the host
/// response could not be parsed (which should never happen - the host
/// always returns a decimal integer).
pub fn nowMs(allocator: std.mem.Allocator) !u64 {
    const bytes = try now(allocator, Format.millis);
    defer allocator.free(bytes);
    return std.fmt.parseInt(u64, bytes, 10) catch 0;
}

/// Convenience: current time as Unix seconds.
pub fn nowUnix(allocator: std.mem.Allocator) !u64 {
    const bytes = try now(allocator, Format.unix);
    defer allocator.free(bytes);
    return std.fmt.parseInt(u64, bytes, 10) catch 0;
}

/// Convenience: current time as an RFC 3339 string.
pub fn nowRfc3339(allocator: std.mem.Allocator) ![]u8 {
    return now(allocator, Format.rfc3339);
}
