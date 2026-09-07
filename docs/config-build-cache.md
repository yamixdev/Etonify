# Prepared config cache

Runtime config preparation uses a single disk entry next to the private
`config.json` file (`config.json.build-cache`). It survives app restarts but
does not keep another subscription or config tree in the UI isolate.

The key covers every `SingboxConfigBuildInput` field except the output path and
the requested result representation. Subscription content, groups, chains,
selection, exclusions, settings and the complete native capabilities contract
are included. Local rule files are streamed through SHA-256: replacing a file
at the same path, even with the same size and timestamp, invalidates the entry.

Hashing, cache decoding and config generation run in a worker isolate. A hit
restores both JSON and build metadata (URLTest tags, outbound indexes and
startup validation results) into a new pending file. The active config is never
trusted as a cache source. Corrupt entries are rebuilt; an optional cache-write
failure does not prevent startup. Required pending-file write failures still
fail startup.

Before returning and promoting a prepared build, the coordinator checks the
current input fingerprint. Cancelled generations cannot be promoted. Startup
validation's invalid-selection-to-lowest fallback is accepted only when the
generated selector already implements that fallback; other selection changes
invalidate the build.

Writes use a flushed temporary file in the same directory and rename to replace
the destination. Do not delete the active file before replacement. Runtime
reconfiguration retains a rollback copy until the native apply succeeds.
Native startup validation and reload preflight checks remain enabled as before;
a cache hit does not bypass native config validation.

## Changing the builder

- Bump `_configCacheSchema` when config-generation or validation semantics change,
  including changes in helpers used by the builder. This invalidates disk entries
  from older client builds even when the core contract has not changed.
- Include new input/capability fields in the fingerprint. A coverage test checks
  that each field is explicitly represented.
- Keep the cache in private storage: it contains proxy credentials, just like
  the active runtime config. Never attach it to logs or diagnostics.
- Use `cacheHit` in the `config performance` log to distinguish reuse from a
  rebuild. Desktop test timings are not Android connection-time measurements.

Tests: `singbox_config_cache_test.dart`, `singbox_config_coordinator_test.dart`.
