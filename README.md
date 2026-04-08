# flaron: Zig SDK

Build **flares** (Wasm functions that run on the [Flaron][flaron] CDN
edge) in idiomatic Zig.

A flare receives an HTTP request (or WebSocket event) at the nearest
edge, runs your Zig code in a sandboxed Wasm runtime, and returns a
response with single-digit-millisecond latency. The host gives the
flare access to per-site KV (Spark), cross-edge CRDT KV (Plasma),
allowlisted secrets, outbound HTTP (Beam), edge-side cryptography,
distributed-friendly ID generators, and structured logging.

[flaron]: https://flaron.dev

---

## Install Zig

Flaron's Zig SDK targets **Zig 0.13 or newer** and is tested on **Zig
0.15.2**.

```sh
brew install zig                      # macOS
sudo pacman -S zig                    # Arch
sudo apt-get install zig              # Debian / Ubuntu (≥ 24.04)
```

Or download a tarball from https://ziglang.org/download/.

```sh
zig version   # → 0.15.2 or newer
```

---

## Quick start: HTTP echo flare

```zig
// src/flare.zig
const std = @import("std");
const flaron = @import("flaron");

comptime {
    flaron.exportAlloc();
}

var body_buf: [4096]u8 = undefined;

export fn handle_request() i64 {
    flaron.resetArena();

    var fba = std.heap.FixedBufferAllocator.init(&body_buf);
    const allocator = fba.allocator();

    const method = flaron.request.method(allocator) catch "GET";
    const url = flaron.request.url(allocator) catch "/";

    var msg_buf: [256]u8 = undefined;
    const msg = std.fmt.bufPrint(
        &msg_buf,
        "hello from a Zig flare\n{s} {s}\n",
        .{ method, url },
    ) catch "hello";

    flaron.response.setStatus(200);
    flaron.response.setHeader("content-type", "text/plain; charset=utf-8");
    flaron.response.setBody(msg);

    return flaron.FlareAction.respond.toI64();
}
```

`build.zig` for your flare:

```zig
const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.resolveTargetQuery(.{
        .cpu_arch = .wasm32,
        .os_tag = .freestanding,
    });

    const flaron = b.dependency("flaron", .{}).module("flaron");

    const exe = b.addExecutable(.{
        .name = "my-flare",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/flare.zig"),
            .target = target,
            .optimize = .ReleaseSmall,
        }),
    });
    exe.entry = .disabled;
    exe.rdynamic = true;
    exe.root_module.addImport("flaron", flaron);
    b.installArtifact(exe);
}
```

Build:

```sh
zig build
```

The compiled module lands at `zig-out/bin/my-flare.wasm`. Upload it
through the Flaron dashboard or `flaronctl`.

---

## What's in the SDK

| Module      | Purpose                                                |
|-------------|--------------------------------------------------------|
| `request`   | Read inbound request: method, URL, headers, body       |
| `response`  | Write outbound response: status, headers, body         |
| `beam`      | Outbound HTTP from inside the flare                    |
| `spark`     | Per-site KV with TTL, persisted on the edge            |
| `plasma`    | Cross-edge CRDT KV: counters, presence, leaderboards   |
| `secrets`   | Read domain-scoped secrets allowlisted for the flare   |
| `crypto`    | Hash, HMAC, JWT, AES-GCM, RNG (host-side)              |
| `encoding`  | Base64, hex, URL encode / decode                       |
| `id`        | UUID v4 / v7, ULID, KSUID, Nanoid, Snowflake           |
| `time`      | Wall-clock timestamps (unix / ms / ns / RFC 3339)      |
| `log`       | Structured info / warn / error logs to the edge slog   |
| `ws`        | WebSocket: send, close, read open / message / close    |

---

## Memory model

Each flare invocation gets a fresh **256 KiB bump arena**. The host
writes return values into the arena via the guest-exported `alloc`
function; the SDK copies the bytes out into a caller-supplied
allocator. Flare authors are expected to:

1. Call `flaron.resetArena()` at the top of every entry-point export.
2. Back the SDK's `[]u8` returns with a `FixedBufferAllocator` (or
   any other allocator). The SDK never holds the allocator after the
   call returns.
3. Wire the `alloc` export with `comptime { flaron.exportAlloc(); }`
   at the crate root, exactly once.

Without `exportAlloc()`, every host function that returns data to the
guest will fail.

---

## Building and testing

```sh
zig build              # builds all examples in zig-out/bin/
zig build test         # runs the unit-test suite on the host
zig build examples     # builds only the example .wasm files
zig fmt --check src/   # verify formatting
```

The unit tests run on the host target. The SDK contains a host stub
that mocks the `flaron/v1` import module so the spec-shaped tests in
`tests/` exercise every code path without needing a Wasm runtime.

---

## Examples

| Example                                          | What it shows                                  |
|--------------------------------------------------|------------------------------------------------|
| [`examples/hello`](examples/hello/)              | Minimal HTTP echo, the smallest useful flare.  |
| [`examples/spark-counter`](examples/spark-counter/) | Per-site visit counter with TTL.            |
| [`examples/plasma-counter`](examples/plasma-counter/) | Globally consistent CRDT counter.         |
| [`examples/secret-jwt`](examples/secret-jwt/)    | Sign a JWT with a domain secret.               |
| [`examples/websocket-echo`](examples/websocket-echo/) | WS open / message / close handlers.       |
| [`examples/beam-fetch`](examples/beam-fetch/)    | Outbound HTTP via Beam.                        |
| [`examples/edge-ops`](examples/edge-ops/)        | Hash, base64, ULID, timestamp.                 |

---

## Documentation

Full Flaron documentation lives at https://flaron.dev. The *Building
Flares* guide walks through configuration, capabilities, deployment,
and troubleshooting in depth.

---

## License

MIT. See [LICENSE](LICENSE).
