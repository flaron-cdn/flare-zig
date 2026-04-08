//! Raw `extern fn` declarations for the `flaron/v1` host module.
//!
//! These declarations are only referenced when the build target is
//! `wasm32-freestanding`. The host writes return values into the guest's
//! linear memory at slots allocated via the guest-exported `alloc` function.
//!
//! Calling convention:
//! - `i64` returns are packed `(ptr << 32) | len` pairs. `0` means "no result".
//! - `i32` returns from write-style functions are status codes.
//! - String/byte arguments are passed as `(ptr, len)` pairs.

pub extern "flaron/v1" fn req_method() i64;
pub extern "flaron/v1" fn req_url() i64;
pub extern "flaron/v1" fn req_header_get(name_ptr: i32, name_len: i32) i64;
pub extern "flaron/v1" fn req_body() i64;

pub extern "flaron/v1" fn resp_set_status(status: i32) void;
pub extern "flaron/v1" fn resp_header_set(name_ptr: i32, name_len: i32, val_ptr: i32, val_len: i32) void;
pub extern "flaron/v1" fn resp_body_set(body_ptr: i32, body_len: i32) void;

pub extern "flaron/v1" fn beam_fetch(url_ptr: i32, url_len: i32, opts_ptr: i32, opts_len: i32) i64;

pub extern "flaron/v1" fn log_info(msg_ptr: i32, msg_len: i32) void;
pub extern "flaron/v1" fn log_warn(msg_ptr: i32, msg_len: i32) void;
pub extern "flaron/v1" fn log_error(msg_ptr: i32, msg_len: i32) void;

pub extern "flaron/v1" fn crypto_hash(args_ptr: i32, args_len: i32) i64;
pub extern "flaron/v1" fn crypto_hmac(args_ptr: i32, args_len: i32) i64;
pub extern "flaron/v1" fn crypto_sign_jwt(args_ptr: i32, args_len: i32) i64;
pub extern "flaron/v1" fn crypto_encrypt_aes(args_ptr: i32, args_len: i32) i64;
pub extern "flaron/v1" fn crypto_decrypt_aes(args_ptr: i32, args_len: i32) i64;
pub extern "flaron/v1" fn crypto_random_bytes(length: i32) i64;

pub extern "flaron/v1" fn encoding_base64_encode(data_ptr: i32, data_len: i32) i64;
pub extern "flaron/v1" fn encoding_base64_decode(data_ptr: i32, data_len: i32) i64;
pub extern "flaron/v1" fn encoding_hex_encode(data_ptr: i32, data_len: i32) i64;
pub extern "flaron/v1" fn encoding_hex_decode(data_ptr: i32, data_len: i32) i64;
pub extern "flaron/v1" fn encoding_url_encode(data_ptr: i32, data_len: i32) i64;
pub extern "flaron/v1" fn encoding_url_decode(data_ptr: i32, data_len: i32) i64;

pub extern "flaron/v1" fn id_uuid(args_ptr: i32, args_len: i32) i64;
pub extern "flaron/v1" fn id_ulid() i64;
pub extern "flaron/v1" fn id_nanoid(length: i32) i64;
pub extern "flaron/v1" fn id_ksuid() i64;
pub extern "flaron/v1" fn id_snowflake() i64;
pub extern "flaron/v1" fn snowflake_id() i64;

pub extern "flaron/v1" fn timestamp(args_ptr: i32, args_len: i32) i64;

pub extern "flaron/v1" fn spark_get(key_ptr: i32, key_len: i32) i64;
pub extern "flaron/v1" fn spark_set(key_ptr: i32, key_len: i32, val_ptr: i32, val_len: i32, ttl_secs: i32) i32;
pub extern "flaron/v1" fn spark_delete(key_ptr: i32, key_len: i32) void;
pub extern "flaron/v1" fn spark_list() i64;
pub extern "flaron/v1" fn spark_pull(origin_ptr: i32, origin_len: i32, keys_ptr: i32, keys_len: i32) i32;

pub extern "flaron/v1" fn plasma_get(key_ptr: i32, key_len: i32) i64;
pub extern "flaron/v1" fn plasma_set(key_ptr: i32, key_len: i32, val_ptr: i32, val_len: i32) i32;
pub extern "flaron/v1" fn plasma_delete(key_ptr: i32, key_len: i32) i32;
pub extern "flaron/v1" fn plasma_increment(key_ptr: i32, key_len: i32, delta: i64) i64;
pub extern "flaron/v1" fn plasma_decrement(key_ptr: i32, key_len: i32, delta: i64) i64;
pub extern "flaron/v1" fn plasma_list() i64;

pub extern "flaron/v1" fn secret_get(key_ptr: i32, key_len: i32) i64;

pub extern "flaron/v1" fn ws_send(data_ptr: i32, data_len: i32) i32;
pub extern "flaron/v1" fn ws_close_conn(code: i32) void;
pub extern "flaron/v1" fn ws_conn_id() i64;
pub extern "flaron/v1" fn ws_event_type() i64;
pub extern "flaron/v1" fn ws_event_data() i64;
pub extern "flaron/v1" fn ws_close_code() i32;
