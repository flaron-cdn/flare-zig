//! Secrets - read domain-scoped secrets allowlisted for this flare.
//!
//! The host enforces an allowlist per flare. Reading a secret that is not
//! in the allowlist returns `null` (and is logged on the host side).

const std = @import("std");
const env = @import("env.zig");

/// Read a secret by name. Returns `null` if the secret does not exist or
/// the flare is not allowed to read it. Caller frees the returned slice.
pub fn get(allocator: std.mem.Allocator, key: []const u8) !?[]u8 {
    return env.secretGet(allocator, key);
}
