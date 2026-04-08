const std = @import("std");
const flaron = @import("flaron");
const testing = std.testing;

fn setup(state: *flaron.env.HostState) void {
    flaron.env.installHostStub(state);
}

test "encoding.base64Encode returns the host result" {
    const allocator = testing.allocator;
    var state: flaron.env.HostState = undefined;
    flaron.env.HostState.init(&state, allocator);
    defer state.deinit();
    state.encoding_b64_encode_result = "aGVsbG8=";
    setup(&state);
    defer flaron.env.uninstallHostStub();

    const out = try flaron.encoding.base64Encode(allocator, "hello");
    defer allocator.free(out);
    try testing.expectEqualStrings("aGVsbG8=", out);
}

test "encoding.base64Decode returns the host result" {
    const allocator = testing.allocator;
    var state: flaron.env.HostState = undefined;
    flaron.env.HostState.init(&state, allocator);
    defer state.deinit();
    state.encoding_b64_decode_result = "hello";
    setup(&state);
    defer flaron.env.uninstallHostStub();

    const out = try flaron.encoding.base64Decode(allocator, "aGVsbG8=");
    defer allocator.free(out);
    try testing.expectEqualStrings("hello", out);
}

test "encoding.hexEncode returns the host result" {
    const allocator = testing.allocator;
    var state: flaron.env.HostState = undefined;
    flaron.env.HostState.init(&state, allocator);
    defer state.deinit();
    state.encoding_hex_encode_result = "68656c6c6f";
    setup(&state);
    defer flaron.env.uninstallHostStub();

    const out = try flaron.encoding.hexEncode(allocator, "hello");
    defer allocator.free(out);
    try testing.expectEqualStrings("68656c6c6f", out);
}

test "encoding.hexDecode returns the host result" {
    const allocator = testing.allocator;
    var state: flaron.env.HostState = undefined;
    flaron.env.HostState.init(&state, allocator);
    defer state.deinit();
    state.encoding_hex_decode_result = "hello";
    setup(&state);
    defer flaron.env.uninstallHostStub();

    const out = try flaron.encoding.hexDecode(allocator, "68656c6c6f");
    defer allocator.free(out);
    try testing.expectEqualStrings("hello", out);
}

test "encoding.urlEncode returns the host result" {
    const allocator = testing.allocator;
    var state: flaron.env.HostState = undefined;
    flaron.env.HostState.init(&state, allocator);
    defer state.deinit();
    state.encoding_url_encode_result = "a%20b";
    setup(&state);
    defer flaron.env.uninstallHostStub();

    const out = try flaron.encoding.urlEncode(allocator, "a b");
    defer allocator.free(out);
    try testing.expectEqualStrings("a%20b", out);
}

test "encoding.urlDecode returns the host result" {
    const allocator = testing.allocator;
    var state: flaron.env.HostState = undefined;
    flaron.env.HostState.init(&state, allocator);
    defer state.deinit();
    state.encoding_url_decode_result = "a b";
    setup(&state);
    defer flaron.env.uninstallHostStub();

    const out = try flaron.encoding.urlDecode(allocator, "a%20b");
    defer allocator.free(out);
    try testing.expectEqualStrings("a b", out);
}
