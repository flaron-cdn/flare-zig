//! Target-aware host bindings.
//!
//! On `wasm32-freestanding` every function below dispatches to a real
//! `extern fn` import in the `flaron/v1` host module and copies any returned
//! bytes out of the per-invocation bump arena into a caller-supplied
//! allocator. On any other target the same function dispatches into
//! `env/host.zig`, the test harness, so the rest of the SDK can be unit
//! tested without a Wasm runtime.
//!
//! Public API of this module is the lowest-level boundary the SDK is allowed
//! to talk to. Everything above (request, response, spark, ...) calls into
//! these functions and is therefore portable across both targets.

const std = @import("std");
const builtin = @import("builtin");

const wasm = @import("env/wasm.zig");
const host = @import("env/host.zig");
const mem = @import("mem.zig");

pub const HostState = host.State;
pub const installHostStub = host.install;
pub const uninstallHostStub = host.uninstall;

const is_wasm = builtin.target.cpu.arch == .wasm32;

fn copyArenaBytes(allocator: std.mem.Allocator, packed_result: i64) !?[]u8 {
    if (packed_result == 0) return null;
    const decoded = mem.decodePtrLen(packed_result);
    if (decoded.len == 0) return try allocator.alloc(u8, 0);
    const slice = @as([*]const u8, @ptrFromInt(@as(usize, decoded.ptr)))[0..decoded.len];
    const out = try allocator.alloc(u8, decoded.len);
    @memcpy(out, slice);
    return out;
}

pub fn reqMethod(allocator: std.mem.Allocator) ![]u8 {
    if (comptime is_wasm) {
        const result = wasm.req_method();
        const bytes = try copyArenaBytes(allocator, result) orelse return allocator.alloc(u8, 0);
        return bytes;
    } else {
        return allocator.dupe(u8, host.req_method());
    }
}

pub fn reqUrl(allocator: std.mem.Allocator) ![]u8 {
    if (comptime is_wasm) {
        const result = wasm.req_url();
        const bytes = try copyArenaBytes(allocator, result) orelse return allocator.alloc(u8, 0);
        return bytes;
    } else {
        return allocator.dupe(u8, host.req_url());
    }
}

pub fn reqHeader(allocator: std.mem.Allocator, name: []const u8) !?[]u8 {
    if (comptime is_wasm) {
        const result = wasm.req_header_get(@intCast(@intFromPtr(name.ptr)), @intCast(name.len));
        return copyArenaBytes(allocator, result);
    } else {
        const value = host.req_header_get(name) orelse return null;
        return try allocator.dupe(u8, value);
    }
}

pub fn reqBody(allocator: std.mem.Allocator) ![]u8 {
    if (comptime is_wasm) {
        const result = wasm.req_body();
        const bytes = try copyArenaBytes(allocator, result) orelse return allocator.alloc(u8, 0);
        return bytes;
    } else {
        return allocator.dupe(u8, host.req_body());
    }
}

pub fn respSetStatus(status: u16) void {
    if (comptime is_wasm) {
        wasm.resp_set_status(@intCast(status));
    } else {
        host.resp_set_status(status);
    }
}

pub fn respHeaderSet(name: []const u8, value: []const u8) void {
    if (comptime is_wasm) {
        wasm.resp_header_set(
            @intCast(@intFromPtr(name.ptr)),
            @intCast(name.len),
            @intCast(@intFromPtr(value.ptr)),
            @intCast(value.len),
        );
    } else {
        host.resp_header_set(name, value);
    }
}

pub fn respBodySet(body: []const u8) void {
    if (comptime is_wasm) {
        wasm.resp_body_set(@intCast(@intFromPtr(body.ptr)), @intCast(body.len));
    } else {
        host.resp_body_set(body);
    }
}

pub fn beamFetch(allocator: std.mem.Allocator, url: []const u8, opts_json: []const u8) !?[]u8 {
    if (comptime is_wasm) {
        const result = wasm.beam_fetch(
            @intCast(@intFromPtr(url.ptr)),
            @intCast(url.len),
            @intCast(@intFromPtr(opts_json.ptr)),
            @intCast(opts_json.len),
        );
        return copyArenaBytes(allocator, result);
    } else {
        const value = host.beam_fetch(url, opts_json) orelse return null;
        return try allocator.dupe(u8, value);
    }
}

pub fn logInfo(msg: []const u8) void {
    if (comptime is_wasm) {
        wasm.log_info(@intCast(@intFromPtr(msg.ptr)), @intCast(msg.len));
    } else {
        host.log_info(msg);
    }
}

pub fn logWarn(msg: []const u8) void {
    if (comptime is_wasm) {
        wasm.log_warn(@intCast(@intFromPtr(msg.ptr)), @intCast(msg.len));
    } else {
        host.log_warn(msg);
    }
}

pub fn logError(msg: []const u8) void {
    if (comptime is_wasm) {
        wasm.log_error(@intCast(@intFromPtr(msg.ptr)), @intCast(msg.len));
    } else {
        host.log_error(msg);
    }
}

const ArgsCall = enum {
    crypto_hash,
    crypto_hmac,
    crypto_sign_jwt,
    crypto_encrypt_aes,
    crypto_decrypt_aes,
    id_uuid,
    timestamp,
};

fn callArgs(allocator: std.mem.Allocator, comptime which: ArgsCall, args_json: []const u8) !?[]u8 {
    if (comptime is_wasm) {
        const ptr: i32 = @intCast(@intFromPtr(args_json.ptr));
        const len: i32 = @intCast(args_json.len);
        const result: i64 = switch (which) {
            .crypto_hash => wasm.crypto_hash(ptr, len),
            .crypto_hmac => wasm.crypto_hmac(ptr, len),
            .crypto_sign_jwt => wasm.crypto_sign_jwt(ptr, len),
            .crypto_encrypt_aes => wasm.crypto_encrypt_aes(ptr, len),
            .crypto_decrypt_aes => wasm.crypto_decrypt_aes(ptr, len),
            .id_uuid => wasm.id_uuid(ptr, len),
            .timestamp => wasm.timestamp(ptr, len),
        };
        return copyArenaBytes(allocator, result);
    } else {
        const value = switch (which) {
            .crypto_hash => host.crypto_hash(args_json),
            .crypto_hmac => host.crypto_hmac(args_json),
            .crypto_sign_jwt => host.crypto_sign_jwt(args_json),
            .crypto_encrypt_aes => host.crypto_encrypt_aes(args_json),
            .crypto_decrypt_aes => host.crypto_decrypt_aes(args_json),
            .id_uuid => host.id_uuid(args_json),
            .timestamp => host.timestamp(args_json),
        };
        if (value.len == 0) return null;
        return try allocator.dupe(u8, value);
    }
}

pub fn cryptoHash(allocator: std.mem.Allocator, args_json: []const u8) !?[]u8 {
    return callArgs(allocator, .crypto_hash, args_json);
}

pub fn cryptoHmac(allocator: std.mem.Allocator, args_json: []const u8) !?[]u8 {
    return callArgs(allocator, .crypto_hmac, args_json);
}

pub fn cryptoSignJwt(allocator: std.mem.Allocator, args_json: []const u8) !?[]u8 {
    return callArgs(allocator, .crypto_sign_jwt, args_json);
}

pub fn cryptoEncryptAes(allocator: std.mem.Allocator, args_json: []const u8) !?[]u8 {
    return callArgs(allocator, .crypto_encrypt_aes, args_json);
}

pub fn cryptoDecryptAes(allocator: std.mem.Allocator, args_json: []const u8) !?[]u8 {
    return callArgs(allocator, .crypto_decrypt_aes, args_json);
}

pub fn cryptoRandomBytes(allocator: std.mem.Allocator, length: u32) !?[]u8 {
    if (comptime is_wasm) {
        const result = wasm.crypto_random_bytes(@intCast(length));
        return copyArenaBytes(allocator, result);
    } else {
        const hex = host.crypto_random_bytes(@intCast(length));
        if (hex.len == 0) return null;
        return try allocator.dupe(u8, hex);
    }
}

const BytesCall = enum {
    base64_encode,
    base64_decode,
    hex_encode,
    hex_decode,
    url_encode,
    url_decode,
};

fn callBytes(allocator: std.mem.Allocator, comptime which: BytesCall, data: []const u8) !?[]u8 {
    if (comptime is_wasm) {
        const ptr: i32 = @intCast(@intFromPtr(data.ptr));
        const len: i32 = @intCast(data.len);
        const result: i64 = switch (which) {
            .base64_encode => wasm.encoding_base64_encode(ptr, len),
            .base64_decode => wasm.encoding_base64_decode(ptr, len),
            .hex_encode => wasm.encoding_hex_encode(ptr, len),
            .hex_decode => wasm.encoding_hex_decode(ptr, len),
            .url_encode => wasm.encoding_url_encode(ptr, len),
            .url_decode => wasm.encoding_url_decode(ptr, len),
        };
        return copyArenaBytes(allocator, result);
    } else {
        const value = switch (which) {
            .base64_encode => host.encoding_base64_encode(data),
            .base64_decode => host.encoding_base64_decode(data),
            .hex_encode => host.encoding_hex_encode(data),
            .hex_decode => host.encoding_hex_decode(data),
            .url_encode => host.encoding_url_encode(data),
            .url_decode => host.encoding_url_decode(data),
        };
        if (value.len == 0) return null;
        return try allocator.dupe(u8, value);
    }
}

pub fn base64Encode(allocator: std.mem.Allocator, data: []const u8) !?[]u8 {
    return callBytes(allocator, .base64_encode, data);
}
pub fn base64Decode(allocator: std.mem.Allocator, data: []const u8) !?[]u8 {
    return callBytes(allocator, .base64_decode, data);
}
pub fn hexEncode(allocator: std.mem.Allocator, data: []const u8) !?[]u8 {
    return callBytes(allocator, .hex_encode, data);
}
pub fn hexDecode(allocator: std.mem.Allocator, data: []const u8) !?[]u8 {
    return callBytes(allocator, .hex_decode, data);
}
pub fn urlEncode(allocator: std.mem.Allocator, data: []const u8) !?[]u8 {
    return callBytes(allocator, .url_encode, data);
}
pub fn urlDecode(allocator: std.mem.Allocator, data: []const u8) !?[]u8 {
    return callBytes(allocator, .url_decode, data);
}

pub fn idUuid(allocator: std.mem.Allocator, args_json: []const u8) !?[]u8 {
    return callArgs(allocator, .id_uuid, args_json);
}

pub fn idUlid(allocator: std.mem.Allocator) !?[]u8 {
    if (comptime is_wasm) {
        return copyArenaBytes(allocator, wasm.id_ulid());
    } else {
        const v = host.id_ulid();
        if (v.len == 0) return null;
        return try allocator.dupe(u8, v);
    }
}

pub fn idNanoid(allocator: std.mem.Allocator, length: u32) !?[]u8 {
    if (comptime is_wasm) {
        return copyArenaBytes(allocator, wasm.id_nanoid(@intCast(length)));
    } else {
        const v = host.id_nanoid(@intCast(length));
        if (v.len == 0) return null;
        return try allocator.dupe(u8, v);
    }
}

pub fn idKsuid(allocator: std.mem.Allocator) !?[]u8 {
    if (comptime is_wasm) {
        return copyArenaBytes(allocator, wasm.id_ksuid());
    } else {
        const v = host.id_ksuid();
        if (v.len == 0) return null;
        return try allocator.dupe(u8, v);
    }
}

pub fn idSnowflake(allocator: std.mem.Allocator) !?[]u8 {
    if (comptime is_wasm) {
        return copyArenaBytes(allocator, wasm.id_snowflake());
    } else {
        const v = host.id_snowflake();
        if (v.len == 0) return null;
        return try allocator.dupe(u8, v);
    }
}

pub fn snowflakeId(allocator: std.mem.Allocator) !?[]u8 {
    if (comptime is_wasm) {
        return copyArenaBytes(allocator, wasm.snowflake_id());
    } else {
        const v = host.snowflake_id();
        if (v.len == 0) return null;
        return try allocator.dupe(u8, v);
    }
}

pub fn timestampFmt(allocator: std.mem.Allocator, args_json: []const u8) !?[]u8 {
    return callArgs(allocator, .timestamp, args_json);
}

pub fn sparkGet(allocator: std.mem.Allocator, key: []const u8) !?[]u8 {
    if (comptime is_wasm) {
        const result = wasm.spark_get(@intCast(@intFromPtr(key.ptr)), @intCast(key.len));
        return copyArenaBytes(allocator, result);
    } else {
        return host.spark_get(allocator, key);
    }
}

pub fn sparkSet(key: []const u8, value: []const u8, ttl_secs: u32) i32 {
    if (comptime is_wasm) {
        return wasm.spark_set(
            @intCast(@intFromPtr(key.ptr)),
            @intCast(key.len),
            @intCast(@intFromPtr(value.ptr)),
            @intCast(value.len),
            @intCast(ttl_secs),
        );
    } else {
        return host.spark_set(key, value, ttl_secs);
    }
}

pub fn sparkDelete(key: []const u8) void {
    if (comptime is_wasm) {
        wasm.spark_delete(@intCast(@intFromPtr(key.ptr)), @intCast(key.len));
    } else {
        host.spark_delete(key);
    }
}

pub fn sparkList(allocator: std.mem.Allocator) !?[]u8 {
    if (comptime is_wasm) {
        return copyArenaBytes(allocator, wasm.spark_list());
    } else {
        return try host.spark_list(allocator);
    }
}

pub fn sparkPull(origin: []const u8, keys_json: []const u8) i32 {
    if (comptime is_wasm) {
        return wasm.spark_pull(
            @intCast(@intFromPtr(origin.ptr)),
            @intCast(origin.len),
            @intCast(@intFromPtr(keys_json.ptr)),
            @intCast(keys_json.len),
        );
    } else {
        return host.spark_pull(origin, keys_json);
    }
}

pub fn plasmaGet(allocator: std.mem.Allocator, key: []const u8) !?[]u8 {
    if (comptime is_wasm) {
        const result = wasm.plasma_get(@intCast(@intFromPtr(key.ptr)), @intCast(key.len));
        return copyArenaBytes(allocator, result);
    } else {
        return host.plasma_get(allocator, key);
    }
}

pub fn plasmaSet(key: []const u8, value: []const u8) i32 {
    if (comptime is_wasm) {
        return wasm.plasma_set(
            @intCast(@intFromPtr(key.ptr)),
            @intCast(key.len),
            @intCast(@intFromPtr(value.ptr)),
            @intCast(value.len),
        );
    } else {
        return host.plasma_set(key, value);
    }
}

pub fn plasmaDelete(key: []const u8) i32 {
    if (comptime is_wasm) {
        return wasm.plasma_delete(@intCast(@intFromPtr(key.ptr)), @intCast(key.len));
    } else {
        return host.plasma_delete(key);
    }
}

pub fn plasmaIncrement(allocator: std.mem.Allocator, key: []const u8, delta: i64) !?[]u8 {
    if (comptime is_wasm) {
        const result = wasm.plasma_increment(
            @intCast(@intFromPtr(key.ptr)),
            @intCast(key.len),
            delta,
        );
        return copyArenaBytes(allocator, result);
    } else {
        return host.plasma_increment(allocator, key, delta);
    }
}

pub fn plasmaDecrement(allocator: std.mem.Allocator, key: []const u8, delta: i64) !?[]u8 {
    if (comptime is_wasm) {
        const result = wasm.plasma_decrement(
            @intCast(@intFromPtr(key.ptr)),
            @intCast(key.len),
            delta,
        );
        return copyArenaBytes(allocator, result);
    } else {
        return host.plasma_decrement(allocator, key, delta);
    }
}

pub fn plasmaList(allocator: std.mem.Allocator) !?[]u8 {
    if (comptime is_wasm) {
        return copyArenaBytes(allocator, wasm.plasma_list());
    } else {
        return try host.plasma_list(allocator);
    }
}

pub fn secretGet(allocator: std.mem.Allocator, key: []const u8) !?[]u8 {
    if (comptime is_wasm) {
        const result = wasm.secret_get(@intCast(@intFromPtr(key.ptr)), @intCast(key.len));
        return copyArenaBytes(allocator, result);
    } else {
        const v = host.secret_get(key) orelse return null;
        return try allocator.dupe(u8, v);
    }
}

pub fn wsSend(data: []const u8) i32 {
    if (comptime is_wasm) {
        return wasm.ws_send(@intCast(@intFromPtr(data.ptr)), @intCast(data.len));
    } else {
        return host.ws_send(data);
    }
}

pub fn wsCloseConn(code: u16) void {
    if (comptime is_wasm) {
        wasm.ws_close_conn(@intCast(code));
    } else {
        host.ws_close_conn(@intCast(code));
    }
}

pub fn wsConnId(allocator: std.mem.Allocator) ![]u8 {
    if (comptime is_wasm) {
        const bytes = try copyArenaBytes(allocator, wasm.ws_conn_id()) orelse return allocator.alloc(u8, 0);
        return bytes;
    } else {
        return allocator.dupe(u8, host.ws_conn_id());
    }
}

pub fn wsEventType(allocator: std.mem.Allocator) ![]u8 {
    if (comptime is_wasm) {
        const bytes = try copyArenaBytes(allocator, wasm.ws_event_type()) orelse return allocator.alloc(u8, 0);
        return bytes;
    } else {
        return allocator.dupe(u8, host.ws_event_type());
    }
}

pub fn wsEventData(allocator: std.mem.Allocator) ![]u8 {
    if (comptime is_wasm) {
        const bytes = try copyArenaBytes(allocator, wasm.ws_event_data()) orelse return allocator.alloc(u8, 0);
        return bytes;
    } else {
        return allocator.dupe(u8, host.ws_event_data());
    }
}

pub fn wsCloseCode() u16 {
    if (comptime is_wasm) {
        return @intCast(@as(u32, @bitCast(wasm.ws_close_code())) & 0xFFFF);
    } else {
        return @intCast(@as(u32, @bitCast(host.ws_close_code())) & 0xFFFF);
    }
}
