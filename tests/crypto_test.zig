const std = @import("std");
const flaron = @import("flaron");
const testing = std.testing;

test "crypto.hash forwards algorithm and input as JSON args" {
    const allocator = testing.allocator;
    var state: flaron.env.HostState = undefined;
    flaron.env.HostState.init(&state, allocator);
    defer state.deinit();
    state.crypto_hash_result = "abc123";
    flaron.env.installHostStub(&state);
    defer flaron.env.uninstallHostStub();

    const out = try flaron.crypto.hash(allocator, "sha256", "data");
    defer allocator.free(out);
    try testing.expectEqualStrings("abc123", out);
    try testing.expect(std.mem.indexOf(u8, state.last_crypto_hash_args, "sha256") != null);
    try testing.expect(std.mem.indexOf(u8, state.last_crypto_hash_args, "data") != null);
}

test "crypto.hmac forwards secret_key and input" {
    const allocator = testing.allocator;
    var state: flaron.env.HostState = undefined;
    flaron.env.HostState.init(&state, allocator);
    defer state.deinit();
    state.crypto_hmac_result = "deadbeef";
    flaron.env.installHostStub(&state);
    defer flaron.env.uninstallHostStub();

    const out = try flaron.crypto.hmac(allocator, "MY_KEY", "payload");
    defer allocator.free(out);
    try testing.expectEqualStrings("deadbeef", out);
    try testing.expect(std.mem.indexOf(u8, state.last_crypto_hmac_args, "MY_KEY") != null);
    try testing.expect(std.mem.indexOf(u8, state.last_crypto_hmac_args, "payload") != null);
}

test "crypto.signJwt embeds the raw claims JSON inside the args" {
    const allocator = testing.allocator;
    var state: flaron.env.HostState = undefined;
    flaron.env.HostState.init(&state, allocator);
    defer state.deinit();
    state.crypto_jwt_result = "header.payload.signature";
    flaron.env.installHostStub(&state);
    defer flaron.env.uninstallHostStub();

    const token = try flaron.crypto.signJwt(allocator, "HS256", "JWT_KEY", "{\"sub\":\"user1\"}");
    defer allocator.free(token);
    try testing.expectEqualStrings("header.payload.signature", token);
    try testing.expect(std.mem.indexOf(u8, state.last_crypto_jwt_args, "HS256") != null);
    try testing.expect(std.mem.indexOf(u8, state.last_crypto_jwt_args, "JWT_KEY") != null);
    try testing.expect(std.mem.indexOf(u8, state.last_crypto_jwt_args, "user1") != null);
}

test "crypto.encryptAes returns the host's base64 ciphertext" {
    const allocator = testing.allocator;
    var state: flaron.env.HostState = undefined;
    flaron.env.HostState.init(&state, allocator);
    defer state.deinit();
    state.crypto_aes_encrypt_result = "Y2lwaGVydGV4dA==";
    flaron.env.installHostStub(&state);
    defer flaron.env.uninstallHostStub();

    const out = try flaron.crypto.encryptAes(allocator, "AES_KEY", "secret");
    defer allocator.free(out);
    try testing.expectEqualStrings("Y2lwaGVydGV4dA==", out);
}

test "crypto.decryptAes returns plaintext bytes" {
    const allocator = testing.allocator;
    var state: flaron.env.HostState = undefined;
    flaron.env.HostState.init(&state, allocator);
    defer state.deinit();
    state.crypto_aes_decrypt_result = "plaintext";
    flaron.env.installHostStub(&state);
    defer flaron.env.uninstallHostStub();

    const out = try flaron.crypto.decryptAes(allocator, "AES_KEY", "Y2lwaGVydGV4dA==");
    defer allocator.free(out);
    try testing.expectEqualStrings("plaintext", out);
}

test "crypto.randomBytes decodes hex from the host into raw bytes" {
    const allocator = testing.allocator;
    var state: flaron.env.HostState = undefined;
    flaron.env.HostState.init(&state, allocator);
    defer state.deinit();
    state.crypto_random_hex = "deadbeef";
    flaron.env.installHostStub(&state);
    defer flaron.env.uninstallHostStub();

    const bytes = try flaron.crypto.randomBytes(allocator, 4);
    defer allocator.free(bytes);
    try testing.expectEqualSlices(u8, &.{ 0xDE, 0xAD, 0xBE, 0xEF }, bytes);
}

test "crypto.randomBytes returns HostFailed when host returns nothing" {
    const allocator = testing.allocator;
    var state: flaron.env.HostState = undefined;
    flaron.env.HostState.init(&state, allocator);
    defer state.deinit();
    state.crypto_random_hex = "";
    flaron.env.installHostStub(&state);
    defer flaron.env.uninstallHostStub();

    try testing.expectError(flaron.crypto.Error.HostFailed, flaron.crypto.randomBytes(allocator, 4));
}

test "crypto.randomBytes returns BadHex when host returns malformed hex" {
    const allocator = testing.allocator;
    var state: flaron.env.HostState = undefined;
    flaron.env.HostState.init(&state, allocator);
    defer state.deinit();
    state.crypto_random_hex = "zzzz";
    flaron.env.installHostStub(&state);
    defer flaron.env.uninstallHostStub();

    try testing.expectError(flaron.crypto.Error.BadHex, flaron.crypto.randomBytes(allocator, 2));
}
