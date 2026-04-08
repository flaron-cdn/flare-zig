//! Spark — per-site local KV with TTL, persisted on the edge node.
//!
//! Reads and writes are quota-limited per invocation. Keys must match
//! `^[a-zA-Z0-9:._\-]{1,256}$` and may not begin with `__flaron:` or
//! `__sys:`. Setting `ttl_secs = 0` means "never expire".

const std = @import("std");
const env = @import("env.zig");
const json = @import("json.zig");

pub const Entry = struct {
    /// Owned by the caller — free with `entry.deinit(allocator)`.
    value: []u8,
    /// Seconds until the host expires this entry. `0` means "no expiry".
    ttl_secs: u32,

    pub fn deinit(self: Entry, allocator: std.mem.Allocator) void {
        allocator.free(self.value);
    }
};

pub const Error = error{
    InvalidTtl,
    TooLarge,
    WriteLimit,
    QuotaExceeded,
    NotAvailable,
    Internal,
    BadKey,
    NoCapability,
    Unknown,
};

pub const PullError = error{
    NotAvailable,
    Internal,
    NoCapability,
    Unknown,
};

fn fromSetCode(code: i32) Error {
    return switch (code) {
        1 => Error.InvalidTtl,
        2 => Error.TooLarge,
        3 => Error.WriteLimit,
        4 => Error.QuotaExceeded,
        5 => Error.NotAvailable,
        6 => Error.Internal,
        8 => Error.BadKey,
        9 => Error.NoCapability,
        else => Error.Unknown,
    };
}

fn fromPullCode(code: i32) PullError {
    return switch (@abs(code)) {
        5 => PullError.NotAvailable,
        6 => PullError.Internal,
        9 => PullError.NoCapability,
        else => PullError.Unknown,
    };
}

/// Get a value from Spark. Returns `null` if the key does not exist.
///
/// The host returns `[4-byte LE u32 TTL][value bytes]`; this function strips
/// the TTL prefix and returns it alongside the raw value bytes.
pub fn get(allocator: std.mem.Allocator, key: []const u8) !?Entry {
    const raw = try env.sparkGet(allocator, key) orelse return null;
    if (raw.len < 4) {
        allocator.free(raw);
        return null;
    }
    const ttl_secs = std.mem.readInt(u32, raw[0..4], .little);
    const value = try allocator.dupe(u8, raw[4..]);
    allocator.free(raw);
    return Entry{ .value = value, .ttl_secs = ttl_secs };
}

/// Convenience: get a value and verify it as a UTF-8 string. Caller frees
/// the returned slice.
pub fn getString(allocator: std.mem.Allocator, key: []const u8) !?[]u8 {
    const entry = try get(allocator, key) orelse return null;
    if (!std.unicode.utf8ValidateSlice(entry.value)) {
        entry.deinit(allocator);
        return null;
    }
    return entry.value;
}

/// Set a value in Spark with a time-to-live in seconds. `ttl_secs = 0`
/// means "never expire".
pub fn set(key: []const u8, value: []const u8, ttl_secs: u32) Error!void {
    const code = env.sparkSet(key, value, ttl_secs);
    if (code == 0) return;
    return fromSetCode(code);
}

/// Delete a key from Spark. No-op if the key does not exist.
pub fn delete(key: []const u8) void {
    env.sparkDelete(key);
}

/// List the keys in this site's Spark namespace. Caller frees the slice
/// and each contained string.
pub fn list(allocator: std.mem.Allocator) ![][]u8 {
    const json_bytes = try env.sparkList(allocator) orelse return allocator.alloc([]u8, 0);
    defer allocator.free(json_bytes);
    return json.parseStringArray(allocator, json_bytes);
}

/// Migrate keys from another node's Spark store into this node. Returns the
/// number of keys successfully migrated.
pub fn pull(allocator: std.mem.Allocator, origin_node: []const u8, keys: []const []const u8) PullError!u32 {
    const keys_json = json.encodeStringArray(allocator, keys) catch return PullError.Internal;
    defer allocator.free(keys_json);
    const code = env.sparkPull(origin_node, keys_json);
    if (code >= 0) return @intCast(code);
    return fromPullCode(code);
}
