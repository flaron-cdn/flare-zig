const std = @import("std");
const flaron = @import("flaron");
const testing = std.testing;

test "plasma.get returns null for missing keys" {
    const allocator = testing.allocator;
    var state: flaron.env.HostState = undefined;
    flaron.env.HostState.init(&state, allocator);
    defer state.deinit();
    flaron.env.installHostStub(&state);
    defer flaron.env.uninstallHostStub();

    try testing.expect((try flaron.plasma.get(allocator, "nope")) == null);
}

test "plasma.get returns the stored value" {
    const allocator = testing.allocator;
    var state: flaron.env.HostState = undefined;
    flaron.env.HostState.init(&state, allocator);
    defer state.deinit();
    try state.plasma_store.put("k", "v");
    flaron.env.installHostStub(&state);
    defer flaron.env.uninstallHostStub();

    const v = (try flaron.plasma.get(allocator, "k")).?;
    defer allocator.free(v);
    try testing.expectEqualStrings("v", v);
}

test "plasma.set stores the value in the harness" {
    const allocator = testing.allocator;
    var state: flaron.env.HostState = undefined;
    flaron.env.HostState.init(&state, allocator);
    defer state.deinit();
    flaron.env.installHostStub(&state);
    defer flaron.env.uninstallHostStub();

    try flaron.plasma.set("k", "v");
    try testing.expectEqualStrings("v", state.plasma_store.get("k").?);
}

test "plasma.set propagates error codes" {
    const allocator = testing.allocator;
    var state: flaron.env.HostState = undefined;
    flaron.env.HostState.init(&state, allocator);
    defer state.deinit();
    state.plasma_set_err_code = 5;
    flaron.env.installHostStub(&state);
    defer flaron.env.uninstallHostStub();

    try testing.expectError(flaron.plasma.Error.NoCapability, flaron.plasma.set("k", "v"));

    state.plasma_set_err_code = 4;
    try testing.expectError(flaron.plasma.Error.BadKey, flaron.plasma.set("k", "v"));
}

test "plasma.delete removes the key" {
    const allocator = testing.allocator;
    var state: flaron.env.HostState = undefined;
    flaron.env.HostState.init(&state, allocator);
    defer state.deinit();
    try state.plasma_store.put("k", "v");
    flaron.env.installHostStub(&state);
    defer flaron.env.uninstallHostStub();

    try flaron.plasma.delete("k");
    try testing.expect(state.plasma_store.get("k") == null);
}

test "plasma.increment decodes the i64 returned by the host" {
    const allocator = testing.allocator;
    var state: flaron.env.HostState = undefined;
    flaron.env.HostState.init(&state, allocator);
    defer state.deinit();
    flaron.env.installHostStub(&state);
    defer flaron.env.uninstallHostStub();

    const v = try flaron.plasma.increment(allocator, "counter", 5);
    try testing.expectEqual(@as(i64, 5), v);

    const v2 = try flaron.plasma.increment(allocator, "counter", 3);
    try testing.expectEqual(@as(i64, 8), v2);
}

test "plasma.decrement decodes the negative-delta result" {
    const allocator = testing.allocator;
    var state: flaron.env.HostState = undefined;
    flaron.env.HostState.init(&state, allocator);
    defer state.deinit();
    flaron.env.installHostStub(&state);
    defer flaron.env.uninstallHostStub();

    _ = try flaron.plasma.increment(allocator, "c", 10);
    const v = try flaron.plasma.decrement(allocator, "c", 3);
    try testing.expectEqual(@as(i64, 7), v);
}

test "plasma.list returns configured keys" {
    const allocator = testing.allocator;
    var state: flaron.env.HostState = undefined;
    flaron.env.HostState.init(&state, allocator);
    defer state.deinit();
    try state.plasma_store.put("a", "1");
    try state.plasma_store.put("b", "2");
    flaron.env.installHostStub(&state);
    defer flaron.env.uninstallHostStub();

    const items = try flaron.plasma.list(allocator);
    defer {
        for (items) |s| allocator.free(s);
        allocator.free(items);
    }
    try testing.expectEqual(@as(usize, 2), items.len);
}
