# spark-counter

Per-site visit counter using **Spark** (per-edge KV with TTL). Each
request reads `visits`, increments it, writes the new value back with a
24-hour TTL, and returns the count.

## Required capability

This flare writes to Spark, so the flare config must enable
`writes_spark_kv = true`. The host returns `NoCapability` otherwise.

## Build

```sh
zig build
```

Output at `zig-out/bin/spark-counter.wasm`.

## Notes

Spark counters are local to the edge node serving the request, so counts
will diverge across edges. For globally consistent counters use
[plasma-counter](../plasma-counter/) instead.
