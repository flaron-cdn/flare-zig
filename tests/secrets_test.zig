const std = @import("std");
const flaron = @import("flaron");
const testing = std.testing;

test "secrets.get returns null when secret is not allowlisted" {
    const allocator = testing.allocator;
    var state: flaron.env.HostState = undefined;
    flaron.env.HostState.init(&state, allocator);
    defer state.deinit();
    flaron.env.installHostStub(&state);
    defer flaron.env.uninstallHostStub();

    try testing.expect((try flaron.secrets.get(allocator, "JWT_SECRET")) == null);
}

test "secrets.get returns the secret value when present" {
    const allocator = testing.allocator;
    var state: flaron.env.HostState = undefined;
    flaron.env.HostState.init(&state, allocator);
    defer state.deinit();
    try state.secrets.put("JWT_SECRET", "shhh");
    flaron.env.installHostStub(&state);
    defer flaron.env.uninstallHostStub();

    const v = (try flaron.secrets.get(allocator, "JWT_SECRET")).?;
    defer allocator.free(v);
    try testing.expectEqualStrings("shhh", v);
    try testing.expectEqualStrings("JWT_SECRET", state.last_secret_key);
}
