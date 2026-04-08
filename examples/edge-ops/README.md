# edge-ops

Exercises four host operations in a single flare: SHA-256 hash, base64
encode, ULID generation, and the current edge timestamp. The response
is a four-line plain-text report.

## Build

```sh
zig build
```

Output at `zig-out/bin/edge-ops.wasm`.

## Why these four?

They cover the most-used categories from the `flaron.crypto`,
`flaron.encoding`, `flaron.id`, and `flaron.time` modules. If you can
build a flare that runs all four cleanly, you can build any
edge-operation flare.
