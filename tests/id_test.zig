const std = @import("std");
const flaron = @import("flaron");
const testing = std.testing;

test "id.uuid forwards version v4 in JSON args" {
    const allocator = testing.allocator;
    var state: flaron.env.HostState = undefined;
    flaron.env.HostState.init(&state, allocator);
    defer state.deinit();
    state.id_uuid_result = "550e8400-e29b-41d4-a716-446655440000";
    flaron.env.installHostStub(&state);
    defer flaron.env.uninstallHostStub();

    const v = try flaron.id.uuid(allocator, .v4);
    defer allocator.free(v);
    try testing.expectEqualStrings("550e8400-e29b-41d4-a716-446655440000", v);
    try testing.expect(std.mem.indexOf(u8, state.last_id_uuid_args, "v4") != null);
}

test "id.uuid forwards version v7 in JSON args" {
    const allocator = testing.allocator;
    var state: flaron.env.HostState = undefined;
    flaron.env.HostState.init(&state, allocator);
    defer state.deinit();
    state.id_uuid_result = "01875e74-3b32-7000-8000-000000000000";
    flaron.env.installHostStub(&state);
    defer flaron.env.uninstallHostStub();

    const v = try flaron.id.uuid(allocator, .v7);
    defer allocator.free(v);
    try testing.expectEqualStrings("01875e74-3b32-7000-8000-000000000000", v);
    try testing.expect(std.mem.indexOf(u8, state.last_id_uuid_args, "v7") != null);
}

test "id.ulid returns the host result" {
    const allocator = testing.allocator;
    var state: flaron.env.HostState = undefined;
    flaron.env.HostState.init(&state, allocator);
    defer state.deinit();
    state.id_ulid_result = "01ARZ3NDEKTSV4RRFFQ69G5FAV";
    flaron.env.installHostStub(&state);
    defer flaron.env.uninstallHostStub();

    const v = try flaron.id.ulid(allocator);
    defer allocator.free(v);
    try testing.expectEqualStrings("01ARZ3NDEKTSV4RRFFQ69G5FAV", v);
}

test "id.nanoid forwards length and returns the host result" {
    const allocator = testing.allocator;
    var state: flaron.env.HostState = undefined;
    flaron.env.HostState.init(&state, allocator);
    defer state.deinit();
    state.id_nanoid_result = "V1StGXR8_Z5jdHi6B-myT";
    flaron.env.installHostStub(&state);
    defer flaron.env.uninstallHostStub();

    const v = try flaron.id.nanoid(allocator, 21);
    defer allocator.free(v);
    try testing.expectEqualStrings("V1StGXR8_Z5jdHi6B-myT", v);
    try testing.expectEqual(@as(i32, 21), state.last_id_nanoid_length);
}

test "id.ksuid returns the host result" {
    const allocator = testing.allocator;
    var state: flaron.env.HostState = undefined;
    flaron.env.HostState.init(&state, allocator);
    defer state.deinit();
    state.id_ksuid_result = "1srOrx2ZWZBpBUvZwXKQmoEYga2";
    flaron.env.installHostStub(&state);
    defer flaron.env.uninstallHostStub();

    const v = try flaron.id.ksuid(allocator);
    defer allocator.free(v);
    try testing.expectEqualStrings("1srOrx2ZWZBpBUvZwXKQmoEYga2", v);
}

test "id.snowflake returns the host result" {
    const allocator = testing.allocator;
    var state: flaron.env.HostState = undefined;
    flaron.env.HostState.init(&state, allocator);
    defer state.deinit();
    state.id_snowflake_result = "1781234567890123456";
    flaron.env.installHostStub(&state);
    defer flaron.env.uninstallHostStub();

    const v = try flaron.id.snowflake(allocator);
    defer allocator.free(v);
    try testing.expectEqualStrings("1781234567890123456", v);
}

test "id.snowflakeDirect uses the dedicated host function" {
    const allocator = testing.allocator;
    var state: flaron.env.HostState = undefined;
    flaron.env.HostState.init(&state, allocator);
    defer state.deinit();
    state.snowflake_id_result = "9999";
    flaron.env.installHostStub(&state);
    defer flaron.env.uninstallHostStub();

    const v = try flaron.id.snowflakeDirect(allocator);
    defer allocator.free(v);
    try testing.expectEqualStrings("9999", v);
}
