# plasma-counter

Globally consistent counter using **Plasma**, Flaron's cross-edge
CRDT KV. Each request increments `global_visits` by 1; the value
converges across every edge node via gossip.

## Required capability

Plasma writes require `writes_plasma_kv = true` on the flare config.
The host returns `NoCapability` otherwise.

## Build

```sh
zig build
```

Output at `zig-out/bin/plasma-counter.wasm`.

## Notes

Use Plasma counters for low-frequency global state (presence,
subscription totals, leaderboards). For per-edge hot counters that can
tolerate divergence, prefer [spark-counter](../spark-counter/).
