const std = @import("std");
const flaron = @import("flaron");
const testing = std.testing;

test "decodePtrLen splits high/low 32 bits" {
    const packed_value = flaron.mem.encodePtrLen(0xDEADBEEF, 0x1234);
    const decoded = flaron.mem.decodePtrLen(packed_value);
    try testing.expectEqual(@as(u32, 0xDEADBEEF), decoded.ptr);
    try testing.expectEqual(@as(u32, 0x1234), decoded.len);
}

test "decodePtrLen handles zero (no-result sentinel)" {
    const decoded = flaron.mem.decodePtrLen(0);
    try testing.expectEqual(@as(u32, 0), decoded.ptr);
    try testing.expectEqual(@as(u32, 0), decoded.len);
}

test "encodePtrLen and decodePtrLen round-trip" {
    const cases = [_]struct { ptr: u32, len: u32 }{
        .{ .ptr = 0, .len = 0 },
        .{ .ptr = 0x100, .len = 16 },
        .{ .ptr = 0xFFFFFFFF, .len = 0xFFFFFFFF },
        .{ .ptr = 1, .len = 1 },
    };
    for (cases) |c| {
        const packed_value = flaron.mem.encodePtrLen(c.ptr, c.len);
        const decoded = flaron.mem.decodePtrLen(packed_value);
        try testing.expectEqual(c.ptr, decoded.ptr);
        try testing.expectEqual(c.len, decoded.len);
    }
}

test "hexDecode parses lowercase and uppercase hex" {
    const allocator = testing.allocator;

    const lower = (try flaron.mem.hexDecode(allocator, "deadbeef")).?;
    defer allocator.free(lower);
    try testing.expectEqualSlices(u8, &.{ 0xDE, 0xAD, 0xBE, 0xEF }, lower);

    const upper = (try flaron.mem.hexDecode(allocator, "DEADBEEF")).?;
    defer allocator.free(upper);
    try testing.expectEqualSlices(u8, &.{ 0xDE, 0xAD, 0xBE, 0xEF }, upper);

    const mixed = (try flaron.mem.hexDecode(allocator, "DeAdBeEf")).?;
    defer allocator.free(mixed);
    try testing.expectEqualSlices(u8, &.{ 0xDE, 0xAD, 0xBE, 0xEF }, mixed);
}

test "hexDecode rejects odd length" {
    const allocator = testing.allocator;
    try testing.expect((try flaron.mem.hexDecode(allocator, "abc")) == null);
}

test "hexDecode rejects non-hex characters" {
    const allocator = testing.allocator;
    try testing.expect((try flaron.mem.hexDecode(allocator, "zz")) == null);
    try testing.expect((try flaron.mem.hexDecode(allocator, "ab cd")) == null);
}

test "hexDecode handles empty input" {
    const allocator = testing.allocator;
    const empty = (try flaron.mem.hexDecode(allocator, "")).?;
    defer allocator.free(empty);
    try testing.expectEqual(@as(usize, 0), empty.len);
}

test "guestAlloc rejects non-positive sizes" {
    try testing.expectEqual(@as(i32, 0), flaron.mem.guestAlloc(0));
    try testing.expectEqual(@as(i32, 0), flaron.mem.guestAlloc(-1));
}

test "guestAlloc bumps the arena offset by aligned size" {
    flaron.mem.resetArena();
    try testing.expectEqual(@as(usize, 0), flaron.mem.arenaUsed());

    try testing.expect(flaron.mem.bumpForTest(16));
    try testing.expectEqual(@as(usize, 16), flaron.mem.arenaUsed());

    try testing.expect(flaron.mem.bumpForTest(32));
    try testing.expectEqual(@as(usize, 48), flaron.mem.arenaUsed());

    flaron.mem.resetArena();
    try testing.expectEqual(@as(usize, 0), flaron.mem.arenaUsed());
}

test "bumpForTest aligns the offset to 8 bytes" {
    flaron.mem.resetArena();
    try testing.expect(flaron.mem.bumpForTest(3));
    try testing.expectEqual(@as(usize, 3), flaron.mem.arenaUsed());

    try testing.expect(flaron.mem.bumpForTest(5));
    try testing.expectEqual(@as(usize, 13), flaron.mem.arenaUsed());

    flaron.mem.resetArena();
}

test "bumpForTest refuses allocations beyond arena capacity" {
    flaron.mem.resetArena();
    try testing.expect(!flaron.mem.bumpForTest(flaron.mem.ARENA_SIZE + 1));
    try testing.expectEqual(@as(usize, 0), flaron.mem.arenaUsed());
}
