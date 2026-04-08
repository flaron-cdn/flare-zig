//! Host-side test harness that mimics the `flaron/v1` host runtime.
//!
//! When the SDK is built for any target other than `wasm32-freestanding`,
//! `env.zig` routes every host call into this harness instead of the real
//! wasm imports. Tests configure the harness with request data, KV state,
//! and mocked responses, then call into the public SDK to verify behaviour.
//!
//! The harness models the host's wire formats exactly so the SDK code paths
//! that parse those wire formats are exercised by tests.

const std = @import("std");

const HashMap = std.StringHashMap;

pub const State = struct {
    backing_allocator: std.mem.Allocator,
    arena: std.heap.ArenaAllocator,
    allocator: std.mem.Allocator = undefined,

    req_method: []const u8 = "",
    req_url: []const u8 = "",
    req_headers: HashMap([]const u8) = undefined,
    req_body: []const u8 = "",

    resp_status: u16 = 0,
    resp_headers: HashMap([]const u8) = undefined,
    resp_body: std.ArrayList(u8) = .{},

    spark_store: HashMap(SparkValue) = undefined,
    spark_get_err: bool = false,
    spark_set_err_code: i32 = 0,
    spark_pull_result: i32 = 0,

    plasma_store: HashMap([]const u8) = undefined,
    plasma_counters: HashMap(i64) = undefined,
    plasma_set_err_code: i32 = 0,

    secrets: HashMap([]const u8) = undefined,

    crypto_hash_result: []const u8 = "",
    crypto_hmac_result: []const u8 = "",
    crypto_jwt_result: []const u8 = "",
    crypto_aes_encrypt_result: []const u8 = "",
    crypto_aes_decrypt_result: []const u8 = "",
    crypto_random_hex: []const u8 = "",

    encoding_b64_encode_result: []const u8 = "",
    encoding_b64_decode_result: []const u8 = "",
    encoding_hex_encode_result: []const u8 = "",
    encoding_hex_decode_result: []const u8 = "",
    encoding_url_encode_result: []const u8 = "",
    encoding_url_decode_result: []const u8 = "",

    id_uuid_result: []const u8 = "",
    id_ulid_result: []const u8 = "",
    id_nanoid_result: []const u8 = "",
    id_ksuid_result: []const u8 = "",
    id_snowflake_result: []const u8 = "",
    snowflake_id_result: []const u8 = "",

    timestamp_result: []const u8 = "",

    beam_response: ?[]const u8 = null,

    log_lines: std.ArrayList(LogLine) = .{},

    ws_event_type: []const u8 = "",
    ws_event_data: []const u8 = "",
    ws_conn_id: []const u8 = "",
    ws_close_code: i32 = 0,
    ws_sent: std.ArrayList([]const u8) = .{},
    ws_send_err: bool = false,
    ws_closed_with: ?i32 = null,

    last_crypto_hash_args: []const u8 = "",
    last_crypto_hmac_args: []const u8 = "",
    last_crypto_jwt_args: []const u8 = "",
    last_crypto_aes_encrypt_args: []const u8 = "",
    last_crypto_aes_decrypt_args: []const u8 = "",
    last_crypto_random_length: i32 = 0,
    last_id_uuid_args: []const u8 = "",
    last_id_nanoid_length: i32 = 0,
    last_timestamp_args: []const u8 = "",
    last_beam_url: []const u8 = "",
    last_beam_opts: []const u8 = "",
    last_secret_key: []const u8 = "",

    pub const SparkValue = struct {
        bytes: []const u8,
        ttl_secs: u32,
    };

    pub const LogLine = struct {
        level: enum { info, warn, err },
        message: []const u8,
    };

    /// Construct a State in place at `out`. The State holds a self-pointer
    /// (the arena allocator's vtable closes over `&out.arena`), so the State
    /// MUST live at a stable address - never copy it after `init`.
    pub fn init(out: *State, backing: std.mem.Allocator) void {
        out.* = .{
            .backing_allocator = backing,
            .arena = std.heap.ArenaAllocator.init(backing),
        };
        out.allocator = out.arena.allocator();
        out.req_headers = HashMap([]const u8).init(out.allocator);
        out.resp_headers = HashMap([]const u8).init(out.allocator);
        out.resp_body = std.ArrayList(u8){};
        out.spark_store = HashMap(SparkValue).init(out.allocator);
        out.plasma_store = HashMap([]const u8).init(out.allocator);
        out.plasma_counters = HashMap(i64).init(out.allocator);
        out.secrets = HashMap([]const u8).init(out.allocator);
        out.log_lines = std.ArrayList(LogLine){};
        out.ws_sent = std.ArrayList([]const u8){};
    }

    pub fn deinit(self: *State) void {
        self.arena.deinit();
    }

    pub fn reset(self: *State) void {
        const backing = self.backing_allocator;
        self.deinit();
        State.init(self, backing);
    }
};

var test_state: ?*State = null;

pub fn install(state: *State) void {
    test_state = state;
}

pub fn uninstall() void {
    test_state = null;
}

fn require() *State {
    return test_state orelse @panic("flaron host stub: no State installed (call install() in test setup)");
}

pub fn req_method() []const u8 {
    return require().req_method;
}

pub fn req_url() []const u8 {
    return require().req_url;
}

pub fn req_header_get(name: []const u8) ?[]const u8 {
    return require().req_headers.get(name);
}

pub fn req_body() []const u8 {
    return require().req_body;
}

pub fn resp_set_status(status: u16) void {
    require().resp_status = status;
}

pub fn resp_header_set(name: []const u8, value: []const u8) void {
    const s = require();
    const dup_name = s.allocator.dupe(u8, name) catch return;
    const dup_val = s.allocator.dupe(u8, value) catch return;
    s.resp_headers.put(dup_name, dup_val) catch return;
}

pub fn resp_body_set(body: []const u8) void {
    const s = require();
    s.resp_body.clearRetainingCapacity();
    s.resp_body.appendSlice(s.allocator, body) catch {};
}

pub fn beam_fetch(url: []const u8, opts: []const u8) ?[]const u8 {
    const s = require();
    s.last_beam_url = dupArena(s, url);
    s.last_beam_opts = dupArena(s, opts);
    return s.beam_response;
}

pub fn log_info(msg: []const u8) void {
    const s = require();
    s.log_lines.append(s.allocator, .{ .level = .info, .message = msg }) catch {};
}

pub fn log_warn(msg: []const u8) void {
    const s = require();
    s.log_lines.append(s.allocator, .{ .level = .warn, .message = msg }) catch {};
}

pub fn log_error(msg: []const u8) void {
    const s = require();
    s.log_lines.append(s.allocator, .{ .level = .err, .message = msg }) catch {};
}

fn dupArena(s: *State, bytes: []const u8) []const u8 {
    return s.allocator.dupe(u8, bytes) catch "";
}

pub fn crypto_hash(args: []const u8) []const u8 {
    const s = require();
    s.last_crypto_hash_args = dupArena(s, args);
    return s.crypto_hash_result;
}

pub fn crypto_hmac(args: []const u8) []const u8 {
    const s = require();
    s.last_crypto_hmac_args = dupArena(s, args);
    return s.crypto_hmac_result;
}

pub fn crypto_sign_jwt(args: []const u8) []const u8 {
    const s = require();
    s.last_crypto_jwt_args = dupArena(s, args);
    return s.crypto_jwt_result;
}

pub fn crypto_encrypt_aes(args: []const u8) []const u8 {
    const s = require();
    s.last_crypto_aes_encrypt_args = dupArena(s, args);
    return s.crypto_aes_encrypt_result;
}

pub fn crypto_decrypt_aes(args: []const u8) []const u8 {
    const s = require();
    s.last_crypto_aes_decrypt_args = dupArena(s, args);
    return s.crypto_aes_decrypt_result;
}

pub fn crypto_random_bytes(length: i32) []const u8 {
    const s = require();
    s.last_crypto_random_length = length;
    return s.crypto_random_hex;
}

pub fn encoding_base64_encode(data: []const u8) []const u8 {
    _ = data;
    return require().encoding_b64_encode_result;
}

pub fn encoding_base64_decode(data: []const u8) []const u8 {
    _ = data;
    return require().encoding_b64_decode_result;
}

pub fn encoding_hex_encode(data: []const u8) []const u8 {
    _ = data;
    return require().encoding_hex_encode_result;
}

pub fn encoding_hex_decode(data: []const u8) []const u8 {
    _ = data;
    return require().encoding_hex_decode_result;
}

pub fn encoding_url_encode(data: []const u8) []const u8 {
    _ = data;
    return require().encoding_url_encode_result;
}

pub fn encoding_url_decode(data: []const u8) []const u8 {
    _ = data;
    return require().encoding_url_decode_result;
}

pub fn id_uuid(args: []const u8) []const u8 {
    const s = require();
    s.last_id_uuid_args = dupArena(s, args);
    return s.id_uuid_result;
}

pub fn id_ulid() []const u8 {
    return require().id_ulid_result;
}

pub fn id_nanoid(length: i32) []const u8 {
    const s = require();
    s.last_id_nanoid_length = length;
    return s.id_nanoid_result;
}

pub fn id_ksuid() []const u8 {
    return require().id_ksuid_result;
}

pub fn id_snowflake() []const u8 {
    return require().id_snowflake_result;
}

pub fn snowflake_id() []const u8 {
    return require().snowflake_id_result;
}

pub fn timestamp(args: []const u8) []const u8 {
    const s = require();
    s.last_timestamp_args = dupArena(s, args);
    return s.timestamp_result;
}

pub fn spark_get(allocator: std.mem.Allocator, key: []const u8) !?[]u8 {
    const s = require();
    if (s.spark_get_err) return null;
    const value = s.spark_store.get(key) orelse return null;
    var out = try allocator.alloc(u8, 4 + value.bytes.len);
    std.mem.writeInt(u32, out[0..4], value.ttl_secs, .little);
    @memcpy(out[4..], value.bytes);
    return out;
}

pub fn spark_set(key: []const u8, value: []const u8, ttl_secs: u32) i32 {
    const s = require();
    if (s.spark_set_err_code != 0) return s.spark_set_err_code;
    const dup_key = s.allocator.dupe(u8, key) catch return 6;
    const dup_val = s.allocator.dupe(u8, value) catch return 6;
    s.spark_store.put(dup_key, .{ .bytes = dup_val, .ttl_secs = ttl_secs }) catch return 6;
    return 0;
}

pub fn spark_delete(key: []const u8) void {
    _ = require().spark_store.remove(key);
}

pub fn spark_list(allocator: std.mem.Allocator) ![]u8 {
    const s = require();
    var list = std.ArrayList(u8){};
    defer list.deinit(allocator);
    try list.append(allocator, '[');
    var first = true;
    var it = s.spark_store.keyIterator();
    while (it.next()) |k| {
        if (!first) try list.append(allocator, ',');
        first = false;
        try list.append(allocator, '"');
        try list.appendSlice(allocator, k.*);
        try list.append(allocator, '"');
    }
    try list.append(allocator, ']');
    return list.toOwnedSlice(allocator);
}

pub fn spark_pull(origin: []const u8, keys_json: []const u8) i32 {
    _ = origin;
    _ = keys_json;
    return require().spark_pull_result;
}

pub fn plasma_get(allocator: std.mem.Allocator, key: []const u8) !?[]u8 {
    const s = require();
    if (s.plasma_store.get(key)) |v| {
        return try allocator.dupe(u8, v);
    }
    return null;
}

pub fn plasma_set(key: []const u8, value: []const u8) i32 {
    const s = require();
    if (s.plasma_set_err_code != 0) return s.plasma_set_err_code;
    const dup_key = s.allocator.dupe(u8, key) catch return 6;
    const dup_val = s.allocator.dupe(u8, value) catch return 6;
    s.plasma_store.put(dup_key, dup_val) catch return 6;
    return 0;
}

pub fn plasma_delete(key: []const u8) i32 {
    _ = require().plasma_store.remove(key);
    return 0;
}

pub fn plasma_increment(allocator: std.mem.Allocator, key: []const u8, delta: i64) !?[]u8 {
    const s = require();
    const current = s.plasma_counters.get(key) orelse 0;
    const new_val = current + delta;
    const dup_key = try s.allocator.dupe(u8, key);
    try s.plasma_counters.put(dup_key, new_val);
    var out = try allocator.alloc(u8, 8);
    std.mem.writeInt(i64, out[0..8], new_val, .little);
    return out;
}

pub fn plasma_decrement(allocator: std.mem.Allocator, key: []const u8, delta: i64) !?[]u8 {
    return plasma_increment(allocator, key, -delta);
}

pub fn plasma_list(allocator: std.mem.Allocator) ![]u8 {
    const s = require();
    var list = std.ArrayList(u8){};
    defer list.deinit(allocator);
    try list.append(allocator, '[');
    var first = true;
    var it = s.plasma_store.keyIterator();
    while (it.next()) |k| {
        if (!first) try list.append(allocator, ',');
        first = false;
        try list.append(allocator, '"');
        try list.appendSlice(allocator, k.*);
        try list.append(allocator, '"');
    }
    try list.append(allocator, ']');
    return list.toOwnedSlice(allocator);
}

pub fn secret_get(key: []const u8) ?[]const u8 {
    const s = require();
    s.last_secret_key = dupArena(s, key);
    return s.secrets.get(key);
}

pub fn ws_send(data: []const u8) i32 {
    const s = require();
    if (s.ws_send_err) return 1;
    const copy = s.allocator.dupe(u8, data) catch return 1;
    s.ws_sent.append(s.allocator, copy) catch return 1;
    return 0;
}

pub fn ws_close_conn(code: i32) void {
    require().ws_closed_with = code;
}

pub fn ws_conn_id() []const u8 {
    return require().ws_conn_id;
}

pub fn ws_event_type() []const u8 {
    return require().ws_event_type;
}

pub fn ws_event_data() []const u8 {
    return require().ws_event_data;
}

pub fn ws_close_code() i32 {
    return require().ws_close_code;
}
