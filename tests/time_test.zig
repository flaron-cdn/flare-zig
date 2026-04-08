const std = @import("std");
const flaron = @import("flaron");
const testing = std.testing;

test "time.now forwards format argument and returns host result" {
    const allocator = testing.allocator;
    var state: flaron.env.HostState = undefined;
    flaron.env.HostState.init(&state, allocator);
    defer state.deinit();
    state.timestamp_result = "2026-04-07T11:12:13Z";
    flaron.env.installHostStub(&state);
    defer flaron.env.uninstallHostStub();

    const v = try flaron.time.now(allocator, flaron.time.Format.rfc3339);
    defer allocator.free(v);
    try testing.expectEqualStrings("2026-04-07T11:12:13Z", v);
    try testing.expect(std.mem.indexOf(u8, state.last_timestamp_args, "rfc3339") != null);
}

test "time.nowMs parses millisecond integer from host" {
    const allocator = testing.allocator;
    var state: flaron.env.HostState = undefined;
    flaron.env.HostState.init(&state, allocator);
    defer state.deinit();
    state.timestamp_result = "1759833600000";
    flaron.env.installHostStub(&state);
    defer flaron.env.uninstallHostStub();

    const ms = try flaron.time.nowMs(allocator);
    try testing.expectEqual(@as(u64, 1759833600000), ms);
}

test "time.nowUnix parses seconds integer from host" {
    const allocator = testing.allocator;
    var state: flaron.env.HostState = undefined;
    flaron.env.HostState.init(&state, allocator);
    defer state.deinit();
    state.timestamp_result = "1759833600";
    flaron.env.installHostStub(&state);
    defer flaron.env.uninstallHostStub();

    const s = try flaron.time.nowUnix(allocator);
    try testing.expectEqual(@as(u64, 1759833600), s);
}

test "time.nowMs returns 0 on unparsable host response" {
    const allocator = testing.allocator;
    var state: flaron.env.HostState = undefined;
    flaron.env.HostState.init(&state, allocator);
    defer state.deinit();
    state.timestamp_result = "not-a-number";
    flaron.env.installHostStub(&state);
    defer flaron.env.uninstallHostStub();

    const ms = try flaron.time.nowMs(allocator);
    try testing.expectEqual(@as(u64, 0), ms);
}
