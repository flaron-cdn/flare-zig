//! WebSocket support - read events, send frames, close the connection.
//!
//! A flare configured for WebSockets is invoked once per event:
//! - `ws_open` - client connected
//! - `ws_message` - frame received
//! - `ws_close` - client (or this flare) closed the connection
//!
//! The export name passed by the host is one of `ws_open`, `ws_message`,
//! `ws_close`. Inside each export, call [`eventType`] to confirm and
//! [`eventData`] / [`closeCode`] to read the payload.

const std = @import("std");
const env = @import("env.zig");

pub const Error = error{
    SendFailed,
};

pub const EventKind = enum {
    open,
    message,
    close,
    unknown,
};

/// Send a frame to the client. Returns `Error.SendFailed` if the host's
/// outbound buffer is full or the connection is no longer alive.
pub fn send(data: []const u8) Error!void {
    const code = env.wsSend(data);
    if (code != 0) return Error.SendFailed;
}

/// Send a UTF-8 string frame to the client.
pub fn sendStr(data: []const u8) Error!void {
    return send(data);
}

/// Close the connection with the given WebSocket close code (e.g. `1000`
/// for normal closure, `1011` for internal error).
pub fn close(code: u16) void {
    env.wsCloseConn(code);
}

/// Connection identifier the host assigned to this WebSocket. Stable for
/// the lifetime of the connection.
pub fn connId(allocator: std.mem.Allocator) ![]u8 {
    return env.wsConnId(allocator);
}

/// The current event type as a parsed [`EventKind`].
pub fn eventType(allocator: std.mem.Allocator) !EventKind {
    const raw = try env.wsEventType(allocator);
    defer allocator.free(raw);
    if (std.mem.eql(u8, raw, "open")) return .open;
    if (std.mem.eql(u8, raw, "message")) return .message;
    if (std.mem.eql(u8, raw, "close")) return .close;
    return .unknown;
}

/// Raw event type string. Use [`eventType`] for the parsed enum.
pub fn eventTypeStr(allocator: std.mem.Allocator) ![]u8 {
    return env.wsEventType(allocator);
}

/// Frame payload for `ws_message` events. Returns an empty slice for
/// `ws_open` and `ws_close` events.
pub fn eventData(allocator: std.mem.Allocator) ![]u8 {
    return env.wsEventData(allocator);
}

/// Close code provided by the remote peer. Only meaningful inside a
/// `ws_close` event handler.
pub fn closeCode() u16 {
    return env.wsCloseCode();
}
