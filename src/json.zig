//! Tiny JSON helpers used by SDK modules.
//!
//! The SDK has no external dependencies, so we ship a minimal encoder for
//! the small set of shapes the host accepts (`{"key":"value"}`-style argument
//! envelopes and `["key", ...]` arrays) and a forgiving parser for the
//! single shape the host returns when listing KV keys.

const std = @import("std");

/// Encode a slice of strings as a JSON array. Caller frees the result.
pub fn encodeStringArray(allocator: std.mem.Allocator, items: []const []const u8) ![]u8 {
    var buf = std.ArrayList(u8){};
    defer buf.deinit(allocator);
    try buf.append(allocator, '[');
    for (items, 0..) |s, i| {
        if (i != 0) try buf.append(allocator, ',');
        try buf.append(allocator, '"');
        try escapeJsonString(allocator, &buf, s);
        try buf.append(allocator, '"');
    }
    try buf.append(allocator, ']');
    return buf.toOwnedSlice(allocator);
}

/// Escape a string into the buffer following JSON string escape rules.
pub fn escapeJsonString(allocator: std.mem.Allocator, out: *std.ArrayList(u8), s: []const u8) !void {
    for (s) |c| {
        switch (c) {
            '"' => try out.appendSlice(allocator, "\\\""),
            '\\' => try out.appendSlice(allocator, "\\\\"),
            '\n' => try out.appendSlice(allocator, "\\n"),
            '\r' => try out.appendSlice(allocator, "\\r"),
            '\t' => try out.appendSlice(allocator, "\\t"),
            0x00...0x08, 0x0B, 0x0C, 0x0E...0x1F => {
                var ubuf: [6]u8 = undefined;
                _ = std.fmt.bufPrint(&ubuf, "\\u{x:0>4}", .{c}) catch unreachable;
                try out.appendSlice(allocator, &ubuf);
            },
            else => try out.append(allocator, c),
        }
    }
}

/// Parse a JSON array of strings. Permissive - handles whitespace, commas,
/// and `\"` escapes. Caller frees the slice and each contained string.
pub fn parseStringArray(allocator: std.mem.Allocator, json: []const u8) ![][]u8 {
    var out = std.ArrayList([]u8){};
    errdefer {
        for (out.items) |s| allocator.free(s);
        out.deinit(allocator);
    }
    var i: usize = 0;
    while (i < json.len and json[i] != '[') i += 1;
    if (i >= json.len) return out.toOwnedSlice(allocator);
    i += 1;
    while (i < json.len) {
        while (i < json.len and (json[i] == ' ' or json[i] == ',' or json[i] == '\n' or json[i] == '\t')) i += 1;
        if (i >= json.len or json[i] == ']') break;
        if (json[i] != '"') break;
        i += 1;
        var unescaped = std.ArrayList(u8){};
        errdefer unescaped.deinit(allocator);
        while (i < json.len and json[i] != '"') {
            if (json[i] == '\\' and i + 1 < json.len) {
                switch (json[i + 1]) {
                    '"' => try unescaped.append(allocator, '"'),
                    '\\' => try unescaped.append(allocator, '\\'),
                    'n' => try unescaped.append(allocator, '\n'),
                    'r' => try unescaped.append(allocator, '\r'),
                    't' => try unescaped.append(allocator, '\t'),
                    else => try unescaped.append(allocator, json[i + 1]),
                }
                i += 2;
            } else {
                try unescaped.append(allocator, json[i]);
                i += 1;
            }
        }
        if (i >= json.len) break;
        try out.append(allocator, try unescaped.toOwnedSlice(allocator));
        i += 1;
    }
    return out.toOwnedSlice(allocator);
}

/// Build a small `{"key":"value", ...}` JSON object from string pairs.
/// Caller frees the result.
pub fn encodeObject(allocator: std.mem.Allocator, pairs: []const [2][]const u8) ![]u8 {
    var buf = std.ArrayList(u8){};
    defer buf.deinit(allocator);
    try buf.append(allocator, '{');
    for (pairs, 0..) |p, i| {
        if (i != 0) try buf.append(allocator, ',');
        try buf.append(allocator, '"');
        try escapeJsonString(allocator, &buf, p[0]);
        try buf.appendSlice(allocator, "\":\"");
        try escapeJsonString(allocator, &buf, p[1]);
        try buf.append(allocator, '"');
    }
    try buf.append(allocator, '}');
    return buf.toOwnedSlice(allocator);
}
