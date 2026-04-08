const std = @import("std");
const flaron = @import("flaron");
const testing = std.testing;

test "request.method returns method from harness" {
    const allocator = testing.allocator;
    var state: flaron.env.HostState = undefined;
    flaron.env.HostState.init(&state, allocator);
    defer state.deinit();
    state.req_method = "POST";
    flaron.env.installHostStub(&state);
    defer flaron.env.uninstallHostStub();

    const m = try flaron.request.method(allocator);
    defer allocator.free(m);
    try testing.expectEqualStrings("POST", m);
}

test "request.method returns empty slice when host has no value" {
    const allocator = testing.allocator;
    var state: flaron.env.HostState = undefined;
    flaron.env.HostState.init(&state, allocator);
    defer state.deinit();
    flaron.env.installHostStub(&state);
    defer flaron.env.uninstallHostStub();

    const m = try flaron.request.method(allocator);
    defer allocator.free(m);
    try testing.expectEqual(@as(usize, 0), m.len);
}

test "request.url returns the configured URL" {
    const allocator = testing.allocator;
    var state: flaron.env.HostState = undefined;
    flaron.env.HostState.init(&state, allocator);
    defer state.deinit();
    state.req_url = "https://example.com/path?q=1";
    flaron.env.installHostStub(&state);
    defer flaron.env.uninstallHostStub();

    const u = try flaron.request.url(allocator);
    defer allocator.free(u);
    try testing.expectEqualStrings("https://example.com/path?q=1", u);
}

test "request.header returns null for missing header" {
    const allocator = testing.allocator;
    var state: flaron.env.HostState = undefined;
    flaron.env.HostState.init(&state, allocator);
    defer state.deinit();
    flaron.env.installHostStub(&state);
    defer flaron.env.uninstallHostStub();

    try testing.expect((try flaron.request.header(allocator, "X-Missing")) == null);
}

test "request.header returns the configured value" {
    const allocator = testing.allocator;
    var state: flaron.env.HostState = undefined;
    flaron.env.HostState.init(&state, allocator);
    defer state.deinit();
    try state.req_headers.put("content-type", "application/json");
    flaron.env.installHostStub(&state);
    defer flaron.env.uninstallHostStub();

    const v = (try flaron.request.header(allocator, "content-type")).?;
    defer allocator.free(v);
    try testing.expectEqualStrings("application/json", v);
}

test "request.body returns the request body bytes" {
    const allocator = testing.allocator;
    var state: flaron.env.HostState = undefined;
    flaron.env.HostState.init(&state, allocator);
    defer state.deinit();
    state.req_body = "{\"hello\":\"world\"}";
    flaron.env.installHostStub(&state);
    defer flaron.env.uninstallHostStub();

    const b = try flaron.request.body(allocator);
    defer allocator.free(b);
    try testing.expectEqualStrings("{\"hello\":\"world\"}", b);
}

test "request.body returns empty slice when no body present" {
    const allocator = testing.allocator;
    var state: flaron.env.HostState = undefined;
    flaron.env.HostState.init(&state, allocator);
    defer state.deinit();
    flaron.env.installHostStub(&state);
    defer flaron.env.uninstallHostStub();

    const b = try flaron.request.body(allocator);
    defer allocator.free(b);
    try testing.expectEqual(@as(usize, 0), b.len);
}
