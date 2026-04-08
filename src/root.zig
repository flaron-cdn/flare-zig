//! # flaron - Zig SDK
//!
//! Build **flares** - Wasm functions that run on the [Flaron][flaron] CDN
//! edge - in idiomatic Zig. A flare receives an HTTP request (or
//! WebSocket event) at the nearest edge, runs your Zig code in a sandboxed
//! Wasm runtime, and returns a response with single-digit-millisecond
//! latency.
//!
//! [flaron]: https://flaron.dev
//!
//! ## Quick start
//!
//! ```zig
//! // src/flare.zig
//! const flaron = @import("flaron");
//!
//! comptime {
//!     flaron.exportAlloc();
//! }
//!
//! export fn handle_request() i64 {
//!     flaron.resetArena();
//!
//!     var buf: [128]u8 = undefined;
//!     var fba = std.heap.FixedBufferAllocator.init(&buf);
//!     const allocator = fba.allocator();
//!
//!     const method = flaron.request.method(allocator) catch "GET";
//!     defer allocator.free(method);
//!
//!     flaron.response.setStatus(200);
//!     flaron.response.setHeader("content-type", "text/plain");
//!     flaron.response.setBodyStr("hello from a Zig flare");
//!
//!     return flaron.FlareAction.respond.toI64();
//! }
//! ```
//!
//! Build with `zig build` - the example targets `wasm32-freestanding` and
//! drops the resulting `.wasm` files in `zig-out/bin/`.
//!
//! ## Modules
//!
//! | Module       | Purpose                                                |
//! |--------------|--------------------------------------------------------|
//! | `request`    | Read inbound request (method, URL, headers, body)      |
//! | `response`   | Write outbound response (status, headers, body)        |
//! | `beam`       | Outbound HTTP from the edge                            |
//! | `spark`      | Per-site KV with TTL, persisted to disk on the edge    |
//! | `plasma`     | Cross-edge CRDT KV - counters, presence, leaderboards  |
//! | `secrets`    | Read domain-scoped secrets allowlisted for this flare  |
//! | `crypto`     | Hash, HMAC, AES-GCM, JWT, RNG                          |
//! | `encoding`   | Base64, hex, URL encode / decode                       |
//! | `id`         | UUID v4 / v7, ULID, KSUID, Nanoid, Snowflake           |
//! | `time`       | Wall-clock timestamps in unix / ms / ns / RFC3339      |
//! | `log`        | Structured info / warn / error logs to the edge slog   |
//! | `ws`         | WebSocket - send, close, read open / message / close   |
//!
//! ## Memory model
//!
//! Each flare invocation gets a fresh 256 KiB bump arena. The host writes
//! return values into the arena via the guest's exported `alloc`, the SDK
//! copies the bytes out into a caller-supplied allocator, and the arena is
//! reset on the next [`resetArena`] call. Flare authors are expected to:
//!
//! 1. Call [`resetArena`] at the top of every entry-point export.
//! 2. Use [`std.heap.FixedBufferAllocator`] (or a `std.heap.page_allocator`)
//!    to back the SDK's `[]u8` returns. The SDK never holds the allocator
//!    after the call returns.

const std = @import("std");

pub const env = @import("env.zig");
pub const mem = @import("mem.zig");
pub const json = @import("json.zig");

pub const request = @import("request.zig");
pub const response = @import("response.zig");
pub const log = @import("log.zig");
pub const time = @import("time.zig");
pub const spark = @import("spark.zig");
pub const plasma = @import("plasma.zig");
pub const secrets = @import("secrets.zig");
pub const crypto = @import("crypto.zig");
pub const encoding = @import("encoding.zig");
pub const id = @import("id.zig");
pub const beam = @import("beam.zig");
pub const ws = @import("ws.zig");

pub const resetArena = mem.resetArena;
pub const guestAlloc = mem.guestAlloc;

/// Action returned by an `handle_request` export to tell the host how to
/// proceed once the flare's body has run.
///
/// The flaron host runtime decodes this from the high 32 bits of the i64
/// return value (`(action << 32)` - produced by [`FlareAction.toI64`]).
pub const FlareAction = enum(u32) {
    /// Send the response the flare just constructed (status, headers,
    /// body set via [`response`]). The typical case.
    respond = 1,

    /// Forward to origin and let the flare transform the upstream
    /// response before it is sent back to the client.
    transform = 2,

    /// Skip the flare entirely on this request - pass through to origin
    /// untouched. Useful for conditional bypass logic.
    pass_through = 3,

    /// Encode this action as the i64 return value of `handle_request`.
    pub fn toI64(self: FlareAction) i64 {
        const u: u64 = @as(u64, @intFromEnum(self)) << 32;
        return @bitCast(u);
    }
};

/// Wire up the guest `alloc` export the flaron host runtime requires.
///
/// Call this in a `comptime` block at the top of your flare:
///
/// ```zig
/// comptime { flaron.exportAlloc(); }
/// ```
///
/// This installs an `extern fn alloc(size: i32) i32` symbol that delegates
/// to [`guestAlloc`]. Without it, every host function that returns data to
/// the guest will fail.
pub fn exportAlloc() void {
    @export(&allocExport, .{ .name = "alloc", .linkage = .strong });
}

fn allocExport(size: i32) callconv(.c) i32 {
    return mem.guestAlloc(size);
}

test {
    std.testing.refAllDecls(@This());
}
