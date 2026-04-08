//! Per-invocation bump arena and host-return parsing helpers.
//!
//! Every host function that returns data does so by writing into the guest's
//! linear memory at a slot the SDK allocates with [`guestAlloc`]. The host
//! returns a packed `(ptr, len)` value that callers decode with [`decodePtrLen`].
//!
//! On non-Wasm targets the arena is unused but still compiles, so the SDK
//! presents a single API to flare authors regardless of where they build.

const std = @import("std");
const builtin = @import("builtin");

pub const PtrLen = struct {
    ptr: u32,
    len: u32,
};

/// Decode a packed `i64` returned from the host into `(ptr, len)`.
///
/// Host convention: high 32 bits = pointer into the guest's address space,
/// low 32 bits = length in bytes.
pub fn decodePtrLen(packed_value: i64) PtrLen {
    const u: u64 = @bitCast(packed_value);
    return .{
        .ptr = @intCast(u >> 32),
        .len = @intCast(u & 0xFFFF_FFFF),
    };
}

/// Encode a `(ptr, len)` pair into the same packed `i64` the host expects.
/// Used by tests; the production data flow only decodes.
pub fn encodePtrLen(ptr: u32, len: u32) i64 {
    const u: u64 = (@as(u64, ptr) << 32) | @as(u64, len);
    return @bitCast(u);
}

/// Decode a hex string into raw bytes. Returns `null` on the first invalid
/// character — callers MUST treat this as a hard failure (corrupted host
/// response, never silently zero-fill, especially for crypto material).
pub fn hexDecode(allocator: std.mem.Allocator, hex: []const u8) !?[]u8 {
    if (hex.len % 2 != 0) return null;
    var out = try allocator.alloc(u8, hex.len / 2);
    errdefer allocator.free(out);
    var i: usize = 0;
    while (i < hex.len) : (i += 2) {
        const hi = hexNibble(hex[i]) orelse {
            allocator.free(out);
            return null;
        };
        const lo = hexNibble(hex[i + 1]) orelse {
            allocator.free(out);
            return null;
        };
        out[i / 2] = (hi << 4) | lo;
    }
    return out;
}

fn hexNibble(c: u8) ?u8 {
    return switch (c) {
        '0'...'9' => c - '0',
        'a'...'f' => c - 'a' + 10,
        'A'...'F' => c - 'A' + 10,
        else => null,
    };
}

// Per-invocation bump allocator
//
// The flaron host calls the guest's exported `alloc(size)` every time it
// needs to hand a value back. A naive global allocator would leak that
// memory for the lifetime of the entire WASM instance — long-lived flares
// would steadily grow until OOM.
//
// Instead we use a per-invocation bump arena. The flare's WASM exports
// (`handle_request`, `ws_open`, `ws_message`, `ws_close`) reset the arena
// at the top of each invocation; everything the host allocates during that
// invocation is reclaimed when control returns to the host.
//
// WASM is single-threaded, so a single mutable arena is sound — there are
// no other threads that could race.

pub const ARENA_SIZE: usize = 256 * 1024;
const ARENA_ALIGN: usize = 8;

var arena_buf: [ARENA_SIZE]u8 align(ARENA_ALIGN) = undefined;
var arena_offset: usize = 0;

/// Reset the bump arena. Called at the top of every flare entry-point export
/// so the next host invocation starts with a fresh 256 KiB scratch space.
pub fn resetArena() void {
    arena_offset = 0;
}

/// Guest memory allocator the host calls (via the `alloc` export wired up
/// in `root.zig`) to write return values into the WASM linear memory. Hands
/// out 8-byte aligned slices from the bump arena.
///
/// Returns `0` on failure (size not positive, arena exhausted) — the host
/// treats `0` as "guest cannot accept this value" and propagates an error.
pub fn guestAlloc(size: i32) i32 {
    if (size <= 0) return 0;
    const sz: usize = @intCast(size);
    const aligned = (arena_offset + (ARENA_ALIGN - 1)) & ~@as(usize, ARENA_ALIGN - 1);
    const end = std.math.add(usize, aligned, sz) catch return 0;
    if (end > ARENA_SIZE) return 0;
    arena_offset = end;
    const base_addr = @intFromPtr(&arena_buf[0]);
    return @intCast(base_addr + aligned);
}

pub fn arenaUsed() usize {
    return arena_offset;
}

/// Test-only helper that runs the bump arena's offset/alignment logic
/// without depending on the host's pointer width. Returns `true` on
/// success, `false` if the allocation would overflow the arena.
pub fn bumpForTest(size: usize) bool {
    const aligned = (arena_offset + (ARENA_ALIGN - 1)) & ~@as(usize, ARENA_ALIGN - 1);
    const end = std.math.add(usize, aligned, size) catch return false;
    if (end > ARENA_SIZE) return false;
    arena_offset = end;
    return true;
}
