//! Distributed-friendly ID generators backed by the host. UUID v4/v7,
//! ULID, KSUID, Nanoid, and Snowflake are all generated on the host so
//! every node sees the same monotonic clock and entropy source.

const std = @import("std");
const env = @import("env.zig");
const json = @import("json.zig");

pub const UuidVersion = enum {
    v4,
    v7,

    fn name(self: UuidVersion) []const u8 {
        return switch (self) {
            .v4 => "v4",
            .v7 => "v7",
        };
    }
};

/// Generate a UUID. Use `.v7` for time-sortable IDs, `.v4` for purely
/// random IDs.
pub fn uuid(allocator: std.mem.Allocator, version: UuidVersion) ![]u8 {
    const args = try json.encodeObject(allocator, &.{.{ "version", version.name() }});
    defer allocator.free(args);
    if (try env.idUuid(allocator, args)) |bytes| return bytes;
    return allocator.alloc(u8, 0);
}

/// Generate a ULID - 26-character Crockford base32, time-sortable.
pub fn ulid(allocator: std.mem.Allocator) ![]u8 {
    if (try env.idUlid(allocator)) |bytes| return bytes;
    return allocator.alloc(u8, 0);
}

/// Generate a Nanoid of the requested length. Pass `0` to use the host
/// default (21 characters).
pub fn nanoid(allocator: std.mem.Allocator, length: u32) ![]u8 {
    if (try env.idNanoid(allocator, length)) |bytes| return bytes;
    return allocator.alloc(u8, 0);
}

/// Generate a KSUID - K-sortable, 27-character base62.
pub fn ksuid(allocator: std.mem.Allocator) ![]u8 {
    if (try env.idKsuid(allocator)) |bytes| return bytes;
    return allocator.alloc(u8, 0);
}

/// Generate a Twitter-style Snowflake ID as a decimal string.
pub fn snowflake(allocator: std.mem.Allocator) ![]u8 {
    if (try env.idSnowflake(allocator)) |bytes| return bytes;
    return allocator.alloc(u8, 0);
}

/// Same as [`snowflake`] but uses the dedicated host function rather than
/// the generic edgeops dispatcher. Both produce identical output.
pub fn snowflakeDirect(allocator: std.mem.Allocator) ![]u8 {
    if (try env.snowflakeId(allocator)) |bytes| return bytes;
    return allocator.alloc(u8, 0);
}
