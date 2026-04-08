const std = @import("std");
const flaron = @import("flaron");
const testing = std.testing;

test "spark.get returns null when key is missing" {
    const allocator = testing.allocator;
    var state: flaron.env.HostState = undefined;
    flaron.env.HostState.init(&state, allocator);
    defer state.deinit();
    flaron.env.installHostStub(&state);
    defer flaron.env.uninstallHostStub();

    try testing.expect((try flaron.spark.get(allocator, "missing")) == null);
}

test "spark.get strips the 4-byte LE TTL prefix" {
    const allocator = testing.allocator;
    var state: flaron.env.HostState = undefined;
    flaron.env.HostState.init(&state, allocator);
    defer state.deinit();
    try state.spark_store.put("k", .{ .bytes = "the-value", .ttl_secs = 3600 });
    flaron.env.installHostStub(&state);
    defer flaron.env.uninstallHostStub();

    const entry = (try flaron.spark.get(allocator, "k")).?;
    defer entry.deinit(allocator);
    try testing.expectEqualStrings("the-value", entry.value);
    try testing.expectEqual(@as(u32, 3600), entry.ttl_secs);
}

test "spark.get tolerates ttl=0 (no expiry) entries" {
    const allocator = testing.allocator;
    var state: flaron.env.HostState = undefined;
    flaron.env.HostState.init(&state, allocator);
    defer state.deinit();
    try state.spark_store.put("forever", .{ .bytes = "x", .ttl_secs = 0 });
    flaron.env.installHostStub(&state);
    defer flaron.env.uninstallHostStub();

    const entry = (try flaron.spark.get(allocator, "forever")).?;
    defer entry.deinit(allocator);
    try testing.expectEqualStrings("x", entry.value);
    try testing.expectEqual(@as(u32, 0), entry.ttl_secs);
}

test "spark.get handles empty value with TTL" {
    const allocator = testing.allocator;
    var state: flaron.env.HostState = undefined;
    flaron.env.HostState.init(&state, allocator);
    defer state.deinit();
    try state.spark_store.put("empty", .{ .bytes = "", .ttl_secs = 60 });
    flaron.env.installHostStub(&state);
    defer flaron.env.uninstallHostStub();

    const entry = (try flaron.spark.get(allocator, "empty")).?;
    defer entry.deinit(allocator);
    try testing.expectEqual(@as(usize, 0), entry.value.len);
    try testing.expectEqual(@as(u32, 60), entry.ttl_secs);
}

test "spark.getString returns the underlying UTF-8 string" {
    const allocator = testing.allocator;
    var state: flaron.env.HostState = undefined;
    flaron.env.HostState.init(&state, allocator);
    defer state.deinit();
    try state.spark_store.put("greet", .{ .bytes = "hello", .ttl_secs = 10 });
    flaron.env.installHostStub(&state);
    defer flaron.env.uninstallHostStub();

    const s = (try flaron.spark.getString(allocator, "greet")).?;
    defer allocator.free(s);
    try testing.expectEqualStrings("hello", s);
}

test "spark.set stores key/value in the harness" {
    const allocator = testing.allocator;
    var state: flaron.env.HostState = undefined;
    flaron.env.HostState.init(&state, allocator);
    defer state.deinit();
    flaron.env.installHostStub(&state);
    defer flaron.env.uninstallHostStub();

    try flaron.spark.set("k", "v", 60);
    const stored = state.spark_store.get("k") orelse return error.NotStored;
    try testing.expectEqualStrings("v", stored.bytes);
    try testing.expectEqual(@as(u32, 60), stored.ttl_secs);
}

test "spark.set propagates host error codes as Error variants" {
    const allocator = testing.allocator;
    var state: flaron.env.HostState = undefined;
    flaron.env.HostState.init(&state, allocator);
    defer state.deinit();
    state.spark_set_err_code = 9;
    flaron.env.installHostStub(&state);
    defer flaron.env.uninstallHostStub();

    try testing.expectError(flaron.spark.Error.NoCapability, flaron.spark.set("k", "v", 60));

    state.spark_set_err_code = 2;
    try testing.expectError(flaron.spark.Error.TooLarge, flaron.spark.set("k", "v", 60));

    state.spark_set_err_code = 1;
    try testing.expectError(flaron.spark.Error.InvalidTtl, flaron.spark.set("k", "v", 60));
}

test "spark.delete removes the key from the store" {
    const allocator = testing.allocator;
    var state: flaron.env.HostState = undefined;
    flaron.env.HostState.init(&state, allocator);
    defer state.deinit();
    try state.spark_store.put("k", .{ .bytes = "v", .ttl_secs = 60 });
    flaron.env.installHostStub(&state);
    defer flaron.env.uninstallHostStub();

    flaron.spark.delete("k");
    try testing.expect(state.spark_store.get("k") == null);
}

test "spark.list returns the configured keys" {
    const allocator = testing.allocator;
    var state: flaron.env.HostState = undefined;
    flaron.env.HostState.init(&state, allocator);
    defer state.deinit();
    try state.spark_store.put("alpha", .{ .bytes = "1", .ttl_secs = 0 });
    try state.spark_store.put("beta", .{ .bytes = "2", .ttl_secs = 0 });
    flaron.env.installHostStub(&state);
    defer flaron.env.uninstallHostStub();

    const items = try flaron.spark.list(allocator);
    defer {
        for (items) |s| allocator.free(s);
        allocator.free(items);
    }
    try testing.expectEqual(@as(usize, 2), items.len);
    var saw_alpha = false;
    var saw_beta = false;
    for (items) |s| {
        if (std.mem.eql(u8, s, "alpha")) saw_alpha = true;
        if (std.mem.eql(u8, s, "beta")) saw_beta = true;
    }
    try testing.expect(saw_alpha and saw_beta);
}

test "spark.pull returns the host count on success" {
    const allocator = testing.allocator;
    var state: flaron.env.HostState = undefined;
    flaron.env.HostState.init(&state, allocator);
    defer state.deinit();
    flaron.env.installHostStub(&state);
    defer flaron.env.uninstallHostStub();

    const n = try flaron.spark.pull(allocator, "edge-sgp", &.{ "k1", "k2" });
    try testing.expectEqual(@as(u32, 0), n);
}

test "spark.pull returns positive count when host reports keys migrated" {
    const allocator = testing.allocator;
    var state: flaron.env.HostState = undefined;
    flaron.env.HostState.init(&state, allocator);
    defer state.deinit();
    state.spark_pull_result = 7;
    flaron.env.installHostStub(&state);
    defer flaron.env.uninstallHostStub();

    const n = try flaron.spark.pull(allocator, "edge-sgp", &.{ "k1", "k2", "k3" });
    try testing.expectEqual(@as(u32, 7), n);
}

test "spark.pull maps negative host codes to typed errors" {
    const allocator = testing.allocator;

    const Case = struct {
        host_code: i32,
        expected: flaron.spark.PullError,
    };
    const cases = [_]Case{
        .{ .host_code = -3, .expected = flaron.spark.PullError.WriteLimit },
        .{ .host_code = -5, .expected = flaron.spark.PullError.NotAvailable },
        .{ .host_code = -6, .expected = flaron.spark.PullError.Internal },
        .{ .host_code = -8, .expected = flaron.spark.PullError.BadKey },
        .{ .host_code = -9, .expected = flaron.spark.PullError.NoCapability },
    };

    for (cases) |c| {
        var state: flaron.env.HostState = undefined;
        flaron.env.HostState.init(&state, allocator);
        defer state.deinit();
        state.spark_pull_result = c.host_code;
        flaron.env.installHostStub(&state);
        defer flaron.env.uninstallHostStub();

        try testing.expectError(
            c.expected,
            flaron.spark.pull(allocator, "edge-sgp", &.{"k"}),
        );
    }
}

test "spark.pull maps unknown negative codes to PullError.Unknown" {
    const allocator = testing.allocator;
    var state: flaron.env.HostState = undefined;
    flaron.env.HostState.init(&state, allocator);
    defer state.deinit();
    state.spark_pull_result = -42;
    flaron.env.installHostStub(&state);
    defer flaron.env.uninstallHostStub();

    try testing.expectError(
        flaron.spark.PullError.Unknown,
        flaron.spark.pull(allocator, "edge-sgp", &.{"k"}),
    );
}
