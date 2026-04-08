//! secret-jwt — sign a JWT using a domain secret.
//!
//! Reads `JWT_SECRET` from the flare's allowlisted secrets, signs an
//! HS256 token with a fixed claims payload, and returns the token in
//! the response body.
//!
//! Configure the flare with `allowed_secrets = ["JWT_SECRET"]` so the
//! host permits the read.

const std = @import("std");
const flaron = @import("flaron");

comptime {
    flaron.exportAlloc();
}

var page_buf: [8192]u8 = undefined;

export fn handle_request() i64 {
    flaron.resetArena();

    var fba = std.heap.FixedBufferAllocator.init(&page_buf);
    const allocator = fba.allocator();

    const claims =
        \\{"sub":"user-42","iat":1759833600,"exp":1759920000}
    ;

    const token = flaron.crypto.signJwt(allocator, "HS256", "JWT_SECRET", claims) catch {
        flaron.response.setStatus(500);
        flaron.response.setBodyStr("jwt signing failed");
        return flaron.FlareAction.respond.toI64();
    };

    flaron.response.setStatus(200);
    flaron.response.setHeader("content-type", "text/plain; charset=utf-8");
    flaron.response.setBody(token);

    return flaron.FlareAction.respond.toI64();
}
