//! websocket-echo - round-trip every received frame back to the client.
//!
//! Demonstrates the WebSocket flare entry points: ws_open / ws_message /
//! ws_close. Each is called by the host with a fresh invocation context.

const std = @import("std");
const flaron = @import("flaron");

comptime {
    flaron.exportAlloc();
}

var ws_buf: [16 * 1024]u8 = undefined;

export fn ws_open() i64 {
    flaron.resetArena();
    flaron.log.info("websocket-echo: client connected");
    return flaron.FlareAction.respond.toI64();
}

export fn ws_message() i64 {
    flaron.resetArena();

    var fba = std.heap.FixedBufferAllocator.init(&ws_buf);
    const allocator = fba.allocator();

    const data = flaron.ws.eventData(allocator) catch {
        return flaron.FlareAction.respond.toI64();
    };

    flaron.ws.send(data) catch |err| {
        flaron.log.err(@errorName(err));
    };

    return flaron.FlareAction.respond.toI64();
}

export fn ws_close() i64 {
    flaron.resetArena();
    flaron.log.info("websocket-echo: client disconnected");
    return flaron.FlareAction.respond.toI64();
}
