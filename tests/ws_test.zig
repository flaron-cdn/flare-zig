const std = @import("std");
const flaron = @import("flaron");
const testing = std.testing;

test "ws.send appends frames to the harness sent queue" {
    const allocator = testing.allocator;
    var state: flaron.env.HostState = undefined;
    flaron.env.HostState.init(&state, allocator);
    defer state.deinit();
    flaron.env.installHostStub(&state);
    defer flaron.env.uninstallHostStub();

    try flaron.ws.send("hello");
    try testing.expectEqual(@as(usize, 1), state.ws_sent.items.len);
    try testing.expectEqualStrings("hello", state.ws_sent.items[0]);
}

test "ws.send returns SendFailed on host error" {
    const allocator = testing.allocator;
    var state: flaron.env.HostState = undefined;
    flaron.env.HostState.init(&state, allocator);
    defer state.deinit();
    state.ws_send_err = true;
    flaron.env.installHostStub(&state);
    defer flaron.env.uninstallHostStub();

    try testing.expectError(flaron.ws.Error.SendFailed, flaron.ws.send("hi"));
}

test "ws.close records the close code" {
    const allocator = testing.allocator;
    var state: flaron.env.HostState = undefined;
    flaron.env.HostState.init(&state, allocator);
    defer state.deinit();
    flaron.env.installHostStub(&state);
    defer flaron.env.uninstallHostStub();

    flaron.ws.close(1000);
    try testing.expectEqual(@as(?i32, 1000), state.ws_closed_with);
}

test "ws.connId returns the host connection identifier" {
    const allocator = testing.allocator;
    var state: flaron.env.HostState = undefined;
    flaron.env.HostState.init(&state, allocator);
    defer state.deinit();
    state.ws_conn_id = "conn-42";
    flaron.env.installHostStub(&state);
    defer flaron.env.uninstallHostStub();

    const id_str = try flaron.ws.connId(allocator);
    defer allocator.free(id_str);
    try testing.expectEqualStrings("conn-42", id_str);
}

test "ws.eventType parses open / message / close strings" {
    const allocator = testing.allocator;
    var state: flaron.env.HostState = undefined;
    flaron.env.HostState.init(&state, allocator);
    defer state.deinit();
    flaron.env.installHostStub(&state);
    defer flaron.env.uninstallHostStub();

    state.ws_event_type = "open";
    try testing.expectEqual(flaron.ws.EventKind.open, try flaron.ws.eventType(allocator));

    state.ws_event_type = "message";
    try testing.expectEqual(flaron.ws.EventKind.message, try flaron.ws.eventType(allocator));

    state.ws_event_type = "close";
    try testing.expectEqual(flaron.ws.EventKind.close, try flaron.ws.eventType(allocator));

    state.ws_event_type = "weird";
    try testing.expectEqual(flaron.ws.EventKind.unknown, try flaron.ws.eventType(allocator));
}

test "ws.eventData returns the message payload" {
    const allocator = testing.allocator;
    var state: flaron.env.HostState = undefined;
    flaron.env.HostState.init(&state, allocator);
    defer state.deinit();
    state.ws_event_data = "frame-payload";
    flaron.env.installHostStub(&state);
    defer flaron.env.uninstallHostStub();

    const data = try flaron.ws.eventData(allocator);
    defer allocator.free(data);
    try testing.expectEqualStrings("frame-payload", data);
}

test "ws.closeCode returns the host close code" {
    const allocator = testing.allocator;
    var state: flaron.env.HostState = undefined;
    flaron.env.HostState.init(&state, allocator);
    defer state.deinit();
    state.ws_close_code = 1006;
    flaron.env.installHostStub(&state);
    defer flaron.env.uninstallHostStub();

    try testing.expectEqual(@as(u16, 1006), flaron.ws.closeCode());
}
