//! Base64, hex, and URL encoding helpers backed by the host. The host
//! implementation is identical across SDKs so flares produce byte-for-byte
//! identical output regardless of language.

const std = @import("std");
const env = @import("env.zig");

pub fn base64Encode(allocator: std.mem.Allocator, data: []const u8) ![]u8 {
    if (try env.base64Encode(allocator, data)) |bytes| return bytes;
    return allocator.alloc(u8, 0);
}

pub fn base64Decode(allocator: std.mem.Allocator, data: []const u8) ![]u8 {
    if (try env.base64Decode(allocator, data)) |bytes| return bytes;
    return allocator.alloc(u8, 0);
}

pub fn hexEncode(allocator: std.mem.Allocator, data: []const u8) ![]u8 {
    if (try env.hexEncode(allocator, data)) |bytes| return bytes;
    return allocator.alloc(u8, 0);
}

pub fn hexDecode(allocator: std.mem.Allocator, data: []const u8) ![]u8 {
    if (try env.hexDecode(allocator, data)) |bytes| return bytes;
    return allocator.alloc(u8, 0);
}

pub fn urlEncode(allocator: std.mem.Allocator, data: []const u8) ![]u8 {
    if (try env.urlEncode(allocator, data)) |bytes| return bytes;
    return allocator.alloc(u8, 0);
}

pub fn urlDecode(allocator: std.mem.Allocator, data: []const u8) ![]u8 {
    if (try env.urlDecode(allocator, data)) |bytes| return bytes;
    return allocator.alloc(u8, 0);
}
