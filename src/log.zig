//! Structured logging from inside a flare.
//!
//! Messages are forwarded to the edge node's `slog` stream tagged with the
//! flare name and domain. The host enforces a per-invocation cap of 100 log
//! lines and truncates each message to 4 KiB.

const env = @import("env.zig");

pub fn info(msg: []const u8) void {
    env.logInfo(msg);
}

pub fn warn(msg: []const u8) void {
    env.logWarn(msg);
}

pub fn err(msg: []const u8) void {
    env.logError(msg);
}
