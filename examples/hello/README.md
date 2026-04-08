# hello

Minimal HTTP echo. Reads the inbound method and URL, responds with a
plain-text body that includes both. The smallest useful Zig flare.

## Build

From the repo root:

```sh
zig build
```

The compiled module lands at `zig-out/bin/hello.wasm`.

## Deploy

Upload `hello.wasm` via the Flaron dashboard or `flaronctl` and bind it
to a route.
