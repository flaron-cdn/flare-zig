//! Edge-side cryptography. All operations execute on the host using the
//! flare's allowlisted secrets - the guest never sees raw key material.

const std = @import("std");
const env = @import("env.zig");
const json = @import("json.zig");
const mem = @import("mem.zig");

pub const Error = error{
    HostFailed,
    BadHex,
};

/// Hash an input string with the named algorithm. Returns a hex-encoded
/// digest. Algorithms supported by the host: `sha256`, `sha512`, `sha1`,
/// `md5`, `blake2b`, `blake3`.
pub fn hash(allocator: std.mem.Allocator, algorithm: []const u8, input: []const u8) ![]u8 {
    const args = try json.encodeObject(allocator, &.{ .{ "algorithm", algorithm }, .{ "input", input } });
    defer allocator.free(args);
    if (try env.cryptoHash(allocator, args)) |bytes| return bytes;
    return allocator.alloc(u8, 0);
}

/// Compute HMAC using a named secret stored in the flare's domain config.
/// `secret_key` is the secret name, not the raw key material.
pub fn hmac(allocator: std.mem.Allocator, secret_key: []const u8, input: []const u8) ![]u8 {
    const args = try json.encodeObject(allocator, &.{ .{ "secret_key", secret_key }, .{ "input", input } });
    defer allocator.free(args);
    if (try env.cryptoHmac(allocator, args)) |bytes| return bytes;
    return allocator.alloc(u8, 0);
}

/// Sign a JWT using a named secret. The host accepts `HS256`, `HS384`,
/// `HS512`, `RS256`, and `EdDSA` depending on the secret type.
pub fn signJwt(
    allocator: std.mem.Allocator,
    algorithm: []const u8,
    secret_key: []const u8,
    claims_json: []const u8,
) ![]u8 {
    var buf = std.ArrayList(u8){};
    defer buf.deinit(allocator);
    try buf.appendSlice(allocator, "{\"algorithm\":\"");
    try json.escapeJsonString(allocator, &buf, algorithm);
    try buf.appendSlice(allocator, "\",\"secret_key\":\"");
    try json.escapeJsonString(allocator, &buf, secret_key);
    try buf.appendSlice(allocator, "\",\"claims\":");
    try buf.appendSlice(allocator, claims_json);
    try buf.append(allocator, '}');
    if (try env.cryptoSignJwt(allocator, buf.items)) |bytes| return bytes;
    return allocator.alloc(u8, 0);
}

/// Encrypt plaintext with AES-GCM using a named secret. Returns
/// base64-encoded ciphertext.
pub fn encryptAes(allocator: std.mem.Allocator, secret_key: []const u8, plaintext: []const u8) ![]u8 {
    const args = try json.encodeObject(allocator, &.{ .{ "secret_key", secret_key }, .{ "input", plaintext } });
    defer allocator.free(args);
    if (try env.cryptoEncryptAes(allocator, args)) |bytes| return bytes;
    return allocator.alloc(u8, 0);
}

/// Decrypt base64-encoded AES-GCM ciphertext with a named secret. Returns
/// raw plaintext bytes.
pub fn decryptAes(allocator: std.mem.Allocator, secret_key: []const u8, ciphertext_b64: []const u8) ![]u8 {
    const args = try json.encodeObject(allocator, &.{ .{ "secret_key", secret_key }, .{ "input", ciphertext_b64 } });
    defer allocator.free(args);
    if (try env.cryptoDecryptAes(allocator, args)) |bytes| return bytes;
    return allocator.alloc(u8, 0);
}

/// Generate cryptographically random bytes. Returns raw bytes (decoded
/// from the host's hex-encoded response).
///
/// Returns `Error.HostFailed` if the host returned no data, or
/// `Error.BadHex` if the host response was not valid hex. Callers MUST
/// treat both as hard failures - silently returning a zeroed buffer would
/// weaken any token or key derived from these bytes.
pub fn randomBytes(allocator: std.mem.Allocator, length: u32) ![]u8 {
    const hex_bytes = try env.cryptoRandomBytes(allocator, length) orelse return Error.HostFailed;
    defer allocator.free(hex_bytes);
    return (try mem.hexDecode(allocator, hex_bytes)) orelse return Error.BadHex;
}
