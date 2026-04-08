# beam-fetch

Proxies the inbound request to https://api.github.com/zen via **Beam**
(outbound HTTP from inside the flare) and returns the upstream body.

## Required configuration

Beam fetches are subject to a per-flare `MaxFetchRequests` limit. The
default is high enough for one fetch per invocation.

## Build

```sh
zig build
```

Output at `zig-out/bin/beam-fetch.wasm`.
