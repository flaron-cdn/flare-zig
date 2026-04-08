const std = @import("std");
const flaron = @import("flaron");
const testing = std.testing;

test "response.setStatus stores the status code" {
    const allocator = testing.allocator;
    var state: flaron.env.HostState = undefined;
    flaron.env.HostState.init(&state, allocator);
    defer state.deinit();
    flaron.env.installHostStub(&state);
    defer flaron.env.uninstallHostStub();

    flaron.response.setStatus(204);
    try testing.expectEqual(@as(u16, 204), state.resp_status);
}

test "response.setHeader stores name and value" {
    const allocator = testing.allocator;
    var state: flaron.env.HostState = undefined;
    flaron.env.HostState.init(&state, allocator);
    defer state.deinit();
    flaron.env.installHostStub(&state);
    defer flaron.env.uninstallHostStub();

    flaron.response.setHeader("content-type", "text/plain");
    const v = state.resp_headers.get("content-type") orelse return error.MissingHeader;
    try testing.expectEqualStrings("text/plain", v);
}

test "response.setBody overwrites previous body bytes" {
    const allocator = testing.allocator;
    var state: flaron.env.HostState = undefined;
    flaron.env.HostState.init(&state, allocator);
    defer state.deinit();
    flaron.env.installHostStub(&state);
    defer flaron.env.uninstallHostStub();

    flaron.response.setBody("first");
    flaron.response.setBody("second");
    try testing.expectEqualStrings("second", state.resp_body.items);
}

test "response.setBodyStr forwards to setBody" {
    const allocator = testing.allocator;
    var state: flaron.env.HostState = undefined;
    flaron.env.HostState.init(&state, allocator);
    defer state.deinit();
    flaron.env.installHostStub(&state);
    defer flaron.env.uninstallHostStub();

    flaron.response.setBodyStr("hello");
    try testing.expectEqualStrings("hello", state.resp_body.items);
}
