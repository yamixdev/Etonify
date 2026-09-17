# Outbound compatibility with sing-box 1.14

`ParsedOutboundSchema.migrateTo114` is shared by subscription import and final
config generation. Saved profiles therefore migrate without reimport. It removes
legacy domain_strategy and maps non-default strategies to domain_resolver,
using dns-local only when no explicit resolver is present. Explicit modern
strategy values win. Detours do not acquire a local resolver from this migration.

Hysteria receive-window and MTU-discovery aliases are removed after copying them
to the shared QUIC fields. Explicit modern values, including zero and false,
win over legacy values. Obsolete ECH flags are removed without altering the
remaining TLS policy. Normalization is idempotent and does not mutate nested
maps belonging to the saved subscription.

The import allowlist accepts shared QUIC fields on Hysteria, Hysteria2 and TUIC,
Gecko packet sizes only on Gecko obfuscation, and TLS handshake_timeout.
Fields discarded by older clients cannot be recovered from their saved copy;
refresh the subscription to import them again.

Config cache schema 2 invalidates configurations prepared before this migration.
No settings migration, new UI, certificate-policy change or native runtime
implementation change is required.

## Tests

Keep `test/fixtures/etonify_schema114.json` identical to
`etonify-core/experimental/libbox/testdata/etonify_schema114.json`. Separate
copies let both repositories run tests without checking out the other project.
A client test checks equality when the core submodule is present.

The Dart tests cover input normalization, subscription import, saved-profile
config generation, precedence and detours. The Go Android corpus test passes
the same expected outbounds to CheckConfig with QUIC and uTLS enabled:

```sh
go test -tags with_quic,with_utls -run TestEtonifyAndroidConfigCorpus ./experimental/libbox
```

References:
- https://sing-box.sagernet.org/migration/
- https://sing-box.sagernet.org/configuration/shared/dial/
- https://sing-box.sagernet.org/configuration/outbound/hysteria/
- https://sing-box.sagernet.org/configuration/shared/quic/
- https://sing-box.sagernet.org/configuration/outbound/hysteria2/
- https://sing-box.sagernet.org/configuration/shared/tls/
