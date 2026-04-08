//! Beam - outbound HTTP fetch from inside a flare.
//!
//! Subject to the per-flare `MaxFetchRequests` limit. Responses are buffered
//! into the per-invocation arena, so callers should keep response bodies
//! reasonably small.

const std = @import("std");
const env = @import("env.zig");
const json = @import("json.zig");

pub const Error = error{
    NoResponse,
    EncodeFailed,
    DecodeFailed,
};

pub const FetchOptions = struct {
    method: []const u8 = "GET",
    headers: []const Header = &.{},
    body: []const u8 = "",

    pub const Header = struct {
        name: []const u8,
        value: []const u8,
    };
};

pub const FetchResponse = struct {
    status: u16,
    body: []u8,
    headers_json: []u8,

    pub fn deinit(self: FetchResponse, allocator: std.mem.Allocator) void {
        allocator.free(self.body);
        allocator.free(self.headers_json);
    }
};

/// Perform an HTTP fetch. Pass `null` for `opts` to issue a default GET.
///
/// The returned response is owned by the caller and must be released with
/// `response.deinit(allocator)`.
pub fn fetch(allocator: std.mem.Allocator, url: []const u8, opts: ?FetchOptions) !FetchResponse {
    const opts_json = try encodeOpts(allocator, opts);
    defer allocator.free(opts_json);

    const raw = try env.beamFetch(allocator, url, opts_json) orelse return Error.NoResponse;
    defer allocator.free(raw);

    return parseResponse(allocator, raw);
}

fn encodeOpts(allocator: std.mem.Allocator, opts: ?FetchOptions) ![]u8 {
    var buf = std.ArrayList(u8){};
    defer buf.deinit(allocator);

    try buf.append(allocator, '{');
    if (opts) |o| {
        var first = true;
        if (o.method.len > 0) {
            try buf.appendSlice(allocator, "\"method\":\"");
            try json.escapeJsonString(allocator, &buf, o.method);
            try buf.append(allocator, '"');
            first = false;
        }
        if (o.headers.len > 0) {
            if (!first) try buf.append(allocator, ',');
            try buf.appendSlice(allocator, "\"headers\":{");
            for (o.headers, 0..) |h, i| {
                if (i != 0) try buf.append(allocator, ',');
                try buf.append(allocator, '"');
                try json.escapeJsonString(allocator, &buf, h.name);
                try buf.appendSlice(allocator, "\":\"");
                try json.escapeJsonString(allocator, &buf, h.value);
                try buf.append(allocator, '"');
            }
            try buf.append(allocator, '}');
            first = false;
        }
        if (o.body.len > 0) {
            if (!first) try buf.append(allocator, ',');
            try buf.appendSlice(allocator, "\"body\":\"");
            try json.escapeJsonString(allocator, &buf, o.body);
            try buf.append(allocator, '"');
        }
    }
    try buf.append(allocator, '}');
    return buf.toOwnedSlice(allocator);
}

fn parseResponse(allocator: std.mem.Allocator, raw: []const u8) !FetchResponse {
    var status: u16 = 0;
    var body_slice: []const u8 = "";
    var headers_slice: []const u8 = "{}";

    if (findJsonInt(raw, "status")) |v| status = @intCast(v);
    if (findJsonString(raw, "body")) |v| body_slice = v;
    if (findJsonObject(raw, "headers")) |v| headers_slice = v;

    const body_unescaped = try unescapeJsonString(allocator, body_slice);
    errdefer allocator.free(body_unescaped);
    const headers_dup = try allocator.dupe(u8, headers_slice);

    return FetchResponse{
        .status = status,
        .body = body_unescaped,
        .headers_json = headers_dup,
    };
}

fn findKey(json_bytes: []const u8, key: []const u8) ?usize {
    var i: usize = 0;
    while (i + key.len + 2 <= json_bytes.len) : (i += 1) {
        if (json_bytes[i] != '"') continue;
        if (i + 1 + key.len + 1 > json_bytes.len) return null;
        if (!std.mem.eql(u8, json_bytes[i + 1 ..][0..key.len], key)) continue;
        if (json_bytes[i + 1 + key.len] != '"') continue;
        var j = i + 2 + key.len;
        while (j < json_bytes.len and (json_bytes[j] == ' ' or json_bytes[j] == ':')) j += 1;
        return j;
    }
    return null;
}

fn findJsonInt(json_bytes: []const u8, key: []const u8) ?i64 {
    const start = findKey(json_bytes, key) orelse return null;
    var end = start;
    while (end < json_bytes.len and (std.ascii.isDigit(json_bytes[end]) or json_bytes[end] == '-')) end += 1;
    if (end == start) return null;
    return std.fmt.parseInt(i64, json_bytes[start..end], 10) catch null;
}

fn findJsonString(json_bytes: []const u8, key: []const u8) ?[]const u8 {
    const start = findKey(json_bytes, key) orelse return null;
    if (start >= json_bytes.len or json_bytes[start] != '"') return null;
    var end = start + 1;
    while (end < json_bytes.len and json_bytes[end] != '"') {
        if (json_bytes[end] == '\\' and end + 1 < json_bytes.len) end += 2 else end += 1;
    }
    if (end >= json_bytes.len) return null;
    return json_bytes[start + 1 .. end];
}

fn findJsonObject(json_bytes: []const u8, key: []const u8) ?[]const u8 {
    const start = findKey(json_bytes, key) orelse return null;
    if (start >= json_bytes.len or json_bytes[start] != '{') return null;
    var depth: usize = 1;
    var end = start + 1;
    while (end < json_bytes.len and depth > 0) : (end += 1) {
        switch (json_bytes[end]) {
            '{' => depth += 1,
            '}' => depth -= 1,
            '"' => {
                end += 1;
                while (end < json_bytes.len and json_bytes[end] != '"') {
                    if (json_bytes[end] == '\\' and end + 1 < json_bytes.len) end += 2 else end += 1;
                }
            },
            else => {},
        }
    }
    return json_bytes[start..end];
}

fn unescapeJsonString(allocator: std.mem.Allocator, src: []const u8) ![]u8 {
    var out = std.ArrayList(u8){};
    errdefer out.deinit(allocator);
    var i: usize = 0;
    while (i < src.len) {
        if (src[i] == '\\' and i + 1 < src.len) {
            switch (src[i + 1]) {
                '"' => try out.append(allocator, '"'),
                '\\' => try out.append(allocator, '\\'),
                'n' => try out.append(allocator, '\n'),
                'r' => try out.append(allocator, '\r'),
                't' => try out.append(allocator, '\t'),
                '/' => try out.append(allocator, '/'),
                else => try out.append(allocator, src[i + 1]),
            }
            i += 2;
        } else {
            try out.append(allocator, src[i]);
            i += 1;
        }
    }
    return out.toOwnedSlice(allocator);
}
