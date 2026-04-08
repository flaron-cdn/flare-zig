//! Read the inbound HTTP request being handled by the flare.
//!
//! Every accessor copies the host's response into a caller-supplied
//! allocator. The bytes are owned by the caller and remain valid until the
//! caller frees them.

const std = @import("std");
const env = @import("env.zig");

/// HTTP method of the inbound request, e.g. `"GET"` or `"POST"`.
///
/// Returns an empty slice only if the host invoked the flare without an
/// active request context, which should never happen in production.
pub fn method(allocator: std.mem.Allocator) ![]u8 {
    return env.reqMethod(allocator);
}

/// Full request URL, including path and query string.
pub fn url(allocator: std.mem.Allocator) ![]u8 {
    return env.reqUrl(allocator);
}

/// Look up a request header by (case-insensitive) name. Returns `null` if
/// the header is absent.
///
/// Note: the flaron host strips `Authorization`, `Cookie`, and any
/// `X-Flaron-*` headers unless the flare is configured with
/// `requires_raw_auth = true`.
pub fn header(allocator: std.mem.Allocator, name: []const u8) !?[]u8 {
    return env.reqHeader(allocator, name);
}

/// Read the request body as raw bytes. Returns an empty slice when the
/// flare is not configured with `requires_body = true`, when the request
/// had no body, or when the body exceeds the host's 10 MiB cap.
pub fn body(allocator: std.mem.Allocator) ![]u8 {
    return env.reqBody(allocator);
}
