const std = @import("std");
const flaron = @import("flaron");
const testing = std.testing;

test "beam.fetch returns NoResponse when host has no result" {
    const allocator = testing.allocator;
    var state: flaron.env.HostState = undefined;
    flaron.env.HostState.init(&state, allocator);
    defer state.deinit();
    flaron.env.installHostStub(&state);
    defer flaron.env.uninstallHostStub();

    try testing.expectError(flaron.beam.Error.NoResponse, flaron.beam.fetch(allocator, "https://example.com", null));
}

test "beam.fetch parses status, body, and headers from the host JSON" {
    const allocator = testing.allocator;
    var state: flaron.env.HostState = undefined;
    flaron.env.HostState.init(&state, allocator);
    defer state.deinit();
    state.beam_response = "{\"status\":200,\"headers\":{\"content-type\":\"text/plain\"},\"body\":\"hello world\"}";
    flaron.env.installHostStub(&state);
    defer flaron.env.uninstallHostStub();

    const resp = try flaron.beam.fetch(allocator, "https://example.com", null);
    defer resp.deinit(allocator);

    try testing.expectEqual(@as(u16, 200), resp.status);
    try testing.expectEqualStrings("hello world", resp.body);
    try testing.expect(std.mem.indexOf(u8, resp.headers_json, "text/plain") != null);
}

test "beam.fetch unescapes \\n and \\\" in the body string" {
    const allocator = testing.allocator;
    var state: flaron.env.HostState = undefined;
    flaron.env.HostState.init(&state, allocator);
    defer state.deinit();
    state.beam_response = "{\"status\":200,\"headers\":{},\"body\":\"line1\\nline2 \\\"quoted\\\"\"}";
    flaron.env.installHostStub(&state);
    defer flaron.env.uninstallHostStub();

    const resp = try flaron.beam.fetch(allocator, "https://example.com", null);
    defer resp.deinit(allocator);
    try testing.expectEqualStrings("line1\nline2 \"quoted\"", resp.body);
}

test "beam.fetch encodes method and headers when opts provided" {
    const allocator = testing.allocator;
    var state: flaron.env.HostState = undefined;
    flaron.env.HostState.init(&state, allocator);
    defer state.deinit();
    state.beam_response = "{\"status\":204,\"headers\":{},\"body\":\"\"}";
    flaron.env.installHostStub(&state);
    defer flaron.env.uninstallHostStub();

    const resp = try flaron.beam.fetch(allocator, "https://example.com/api", .{
        .method = "POST",
        .headers = &.{
            .{ .name = "content-type", .value = "application/json" },
            .{ .name = "x-trace", .value = "abc" },
        },
        .body = "{\"k\":\"v\"}",
    });
    defer resp.deinit(allocator);

    try testing.expectEqualStrings("https://example.com/api", state.last_beam_url);
    try testing.expect(std.mem.indexOf(u8, state.last_beam_opts, "POST") != null);
    try testing.expect(std.mem.indexOf(u8, state.last_beam_opts, "content-type") != null);
    try testing.expect(std.mem.indexOf(u8, state.last_beam_opts, "x-trace") != null);
    try testing.expect(std.mem.indexOf(u8, state.last_beam_opts, "{\\\"k\\\":\\\"v\\\"}") != null);
}
