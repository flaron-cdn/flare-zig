# secret-jwt

Sign a JWT using a domain secret pulled through Flaron's secrets
allowlist. Demonstrates `crypto.signJwt` and the secrets capability
gate.

## Required configuration

The flare's domain config must include the secret name in
`allowed_secrets`:

```toml
allowed_secrets = ["JWT_SECRET"]
```

The host enforces the allowlist; reads of any other secret name
return `null`.

## Build

```sh
zig build
```

Output at `zig-out/bin/secret-jwt.wasm`.
