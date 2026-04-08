const std = @import("std");
const flaron = @import("flaron");
const testing = std.testing;

test "encodeStringArray emits JSON array" {
    const allocator = testing.allocator;
    const out = try flaron.json.encodeStringArray(allocator, &.{ "a", "b", "c" });
    defer allocator.free(out);
    try testing.expectEqualStrings("[\"a\",\"b\",\"c\"]", out);
}

test "encodeStringArray escapes quotes and backslashes" {
    const allocator = testing.allocator;
    const out = try flaron.json.encodeStringArray(allocator, &.{ "a\"b", "c\\d" });
    defer allocator.free(out);
    try testing.expectEqualStrings("[\"a\\\"b\",\"c\\\\d\"]", out);
}

test "encodeStringArray handles empty input" {
    const allocator = testing.allocator;
    const out = try flaron.json.encodeStringArray(allocator, &.{});
    defer allocator.free(out);
    try testing.expectEqualStrings("[]", out);
}

test "parseStringArray reads simple JSON array" {
    const allocator = testing.allocator;
    const items = try flaron.json.parseStringArray(allocator, "[\"a\",\"b\",\"c\"]");
    defer {
        for (items) |s| allocator.free(s);
        allocator.free(items);
    }
    try testing.expectEqual(@as(usize, 3), items.len);
    try testing.expectEqualStrings("a", items[0]);
    try testing.expectEqualStrings("b", items[1]);
    try testing.expectEqualStrings("c", items[2]);
}

test "parseStringArray decodes escape sequences" {
    const allocator = testing.allocator;
    const items = try flaron.json.parseStringArray(allocator, "[\"line1\\nline2\",\"q\\\"q\",\"slash\\\\\"]");
    defer {
        for (items) |s| allocator.free(s);
        allocator.free(items);
    }
    try testing.expectEqual(@as(usize, 3), items.len);
    try testing.expectEqualStrings("line1\nline2", items[0]);
    try testing.expectEqualStrings("q\"q", items[1]);
    try testing.expectEqualStrings("slash\\", items[2]);
}

test "parseStringArray handles empty array" {
    const allocator = testing.allocator;
    const items = try flaron.json.parseStringArray(allocator, "[]");
    defer allocator.free(items);
    try testing.expectEqual(@as(usize, 0), items.len);
}

test "encodeObject emits JSON object" {
    const allocator = testing.allocator;
    const out = try flaron.json.encodeObject(allocator, &.{ .{ "k1", "v1" }, .{ "k2", "v2" } });
    defer allocator.free(out);
    try testing.expectEqualStrings("{\"k1\":\"v1\",\"k2\":\"v2\"}", out);
}

test "encodeObject escapes special characters in keys and values" {
    const allocator = testing.allocator;
    const out = try flaron.json.encodeObject(allocator, &.{.{ "k\"k", "v\nv" }});
    defer allocator.free(out);
    try testing.expectEqualStrings("{\"k\\\"k\":\"v\\nv\"}", out);
}
