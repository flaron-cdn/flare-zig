const std = @import("std");
const flaron = @import("flaron");
const testing = std.testing;

test "log.info appends an info-level line" {
    const allocator = testing.allocator;
    var state: flaron.env.HostState = undefined;
    flaron.env.HostState.init(&state, allocator);
    defer state.deinit();
    flaron.env.installHostStub(&state);
    defer flaron.env.uninstallHostStub();

    flaron.log.info("an info message");
    try testing.expectEqual(@as(usize, 1), state.log_lines.items.len);
    try testing.expectEqual(@as(@TypeOf(state.log_lines.items[0].level), .info), state.log_lines.items[0].level);
    try testing.expectEqualStrings("an info message", state.log_lines.items[0].message);
}

test "log.warn appends a warn-level line" {
    const allocator = testing.allocator;
    var state: flaron.env.HostState = undefined;
    flaron.env.HostState.init(&state, allocator);
    defer state.deinit();
    flaron.env.installHostStub(&state);
    defer flaron.env.uninstallHostStub();

    flaron.log.warn("a warning");
    try testing.expectEqual(@as(usize, 1), state.log_lines.items.len);
    try testing.expectEqual(@as(@TypeOf(state.log_lines.items[0].level), .warn), state.log_lines.items[0].level);
    try testing.expectEqualStrings("a warning", state.log_lines.items[0].message);
}

test "log.err appends an error-level line" {
    const allocator = testing.allocator;
    var state: flaron.env.HostState = undefined;
    flaron.env.HostState.init(&state, allocator);
    defer state.deinit();
    flaron.env.installHostStub(&state);
    defer flaron.env.uninstallHostStub();

    flaron.log.err("things broke");
    try testing.expectEqual(@as(usize, 1), state.log_lines.items.len);
    try testing.expectEqual(@as(@TypeOf(state.log_lines.items[0].level), .err), state.log_lines.items[0].level);
    try testing.expectEqualStrings("things broke", state.log_lines.items[0].message);
}

test "log calls accumulate in order" {
    const allocator = testing.allocator;
    var state: flaron.env.HostState = undefined;
    flaron.env.HostState.init(&state, allocator);
    defer state.deinit();
    flaron.env.installHostStub(&state);
    defer flaron.env.uninstallHostStub();

    flaron.log.info("one");
    flaron.log.warn("two");
    flaron.log.err("three");
    try testing.expectEqual(@as(usize, 3), state.log_lines.items.len);
}
