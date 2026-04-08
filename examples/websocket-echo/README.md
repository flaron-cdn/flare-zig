# websocket-echo

Echoes every received WebSocket frame back to the client. Demonstrates
the three WebSocket entry points: `ws_open`, `ws_message`, `ws_close`.

## Required configuration

Mark the flare as a WebSocket flare in its config so the host upgrades
incoming connections and routes events to the right exports.

## Build

```sh
zig build
```

Output at `zig-out/bin/websocket-echo.wasm`.

## Test locally

```sh
websocat ws://your-edge.example.com/echo
> hello
< hello
```
