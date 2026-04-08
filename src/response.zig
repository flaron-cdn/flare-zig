//! Build the outbound HTTP response.
//!
//! Each setter mutates host-side state for the current invocation. The flare
//! must return `FlareAction.respond.toI64()` from its `handle_request`
//! export for the assembled response to be sent to the client.

const env = @import("env.zig");

/// Set the HTTP status code (defaults to `200` if never called).
pub fn setStatus(code: u16) void {
    env.respSetStatus(code);
}

/// Set a response header. Calling with the same name twice overwrites the
/// previous value — there is no append semantics.
///
/// Header names are case-insensitive at the wire level but the host
/// preserves whatever casing you pass.
pub fn setHeader(name: []const u8, value: []const u8) void {
    env.respHeaderSet(name, value);
}

/// Set the response body as raw bytes. Pass an empty slice for an empty body.
pub fn setBody(body: []const u8) void {
    env.respBodySet(body);
}

/// Convenience: set the response body from a string slice.
pub fn setBodyStr(body: []const u8) void {
    env.respBodySet(body);
}
