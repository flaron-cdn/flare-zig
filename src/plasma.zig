//! Plasma - cross-edge CRDT KV.
//!
//! Plasma values converge across all edge nodes via gossip. Counters use
//! `increment`/`decrement` and return the new aggregate value as a signed
//! 64-bit integer.

const std = @import("std");
const env = @import("env.zig");
const json = @import("json.zig");

pub const Error = error{
    NotAvailable,
    WriteLimit,
    TooLarge,
    BadKey,
    NoCapability,
    Internal,
    Unknown,
};

fn fromCode(code: i32) Error {
    return switch (code) {
        1 => Error.NotAvailable,
        2 => Error.WriteLimit,
        3 => Error.TooLarge,
        4 => Error.BadKey,
        5 => Error.NoCapability,
        6 => Error.Internal,
        else => Error.Unknown,
    };
}

/// Get a value from Plasma. Returns `null` if the key does not exist.
/// Caller frees the returned slice.
pub fn get(allocator: std.mem.Allocator, key: []const u8) !?[]u8 {
    return env.plasmaGet(allocator, key);
}

/// Set a value in Plasma.
pub fn set(key: []const u8, value: []const u8) Error!void {
    const code = env.plasmaSet(key, value);
    if (code == 0) return;
    return fromCode(code);
}

/// Delete a key from Plasma.
pub fn delete(key: []const u8) Error!void {
    const code = env.plasmaDelete(key);
    if (code == 0) return;
    return fromCode(code);
}

/// Increment a counter by `delta` and return the new aggregate value.
///
/// The host returns 8 little-endian bytes encoding the new `i64` value.
pub fn increment(allocator: std.mem.Allocator, key: []const u8, delta: i64) !i64 {
    const raw = try env.plasmaIncrement(allocator, key, delta) orelse return 0;
    defer allocator.free(raw);
    if (raw.len < 8) return 0;
    return std.mem.readInt(i64, raw[0..8], .little);
}

/// Decrement a counter by `delta` and return the new aggregate value.
pub fn decrement(allocator: std.mem.Allocator, key: []const u8, delta: i64) !i64 {
    const raw = try env.plasmaDecrement(allocator, key, delta) orelse return 0;
    defer allocator.free(raw);
    if (raw.len < 8) return 0;
    return std.mem.readInt(i64, raw[0..8], .little);
}

/// List all keys in this site's Plasma namespace. Caller frees the slice
/// and each contained string.
pub fn list(allocator: std.mem.Allocator) ![][]u8 {
    const json_bytes = try env.plasmaList(allocator) orelse return allocator.alloc([]u8, 0);
    defer allocator.free(json_bytes);
    return json.parseStringArray(allocator, json_bytes);
}
