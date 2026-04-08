const std = @import("std");
const flaron = @import("flaron");
const testing = std.testing;

test "FlareAction.respond encodes action 1 in high 32 bits" {
    const v = flaron.FlareAction.respond.toI64();
    const expected: i64 = @bitCast(@as(u64, 1) << 32);
    try testing.expectEqual(expected, v);
}

test "FlareAction.transform encodes action 2 in high 32 bits" {
    const v = flaron.FlareAction.transform.toI64();
    const expected: i64 = @bitCast(@as(u64, 2) << 32);
    try testing.expectEqual(expected, v);
}

test "FlareAction.pass_through encodes action 3 in high 32 bits" {
    const v = flaron.FlareAction.pass_through.toI64();
    const expected: i64 = @bitCast(@as(u64, 3) << 32);
    try testing.expectEqual(expected, v);
}

test "FlareAction values match Rust SDK enum" {
    try testing.expectEqual(@as(u32, 1), @intFromEnum(flaron.FlareAction.respond));
    try testing.expectEqual(@as(u32, 2), @intFromEnum(flaron.FlareAction.transform));
    try testing.expectEqual(@as(u32, 3), @intFromEnum(flaron.FlareAction.pass_through));
}
