# Core settings

The section is opt-in. All defaults preserve the existing generated config,
including any compatible provider multiplex settings. The UI edits a local
draft; only Apply or a confirmed Reset submits one configuration transaction.
DNS, routing, TUN MTU/stack, TLS certificate policy and experimental controls
remain on their existing pages.

## Data flow

- `CoreSettings` is persisted as versioned JSON in `core_settings_v1`.
  Missing/invalid values fall back to defaults. It participates in settings
  backup and the background config fingerprint.
- The entry notice is a separate, local preference. It is not exported and
  resetting this section does not clear it.
- Snapshot -> background build input -> builder -> `applyCoreSettings`.
  Apply only touches freshly built maps, not subscription payloads.
- Network defaults go to `route`. Explicit provider dial/interface settings
  retain native precedence. Network availability remains platform-dependent.
- UDP NAT settings only affect TUN. Connect/keepalive/fragment settings affect
  proxy dialers, not selectors/direct or the socket settings of detoured hops.
  TCP keepalive and TLS handshake overrides do not target QUIC.
- A changed section requires a full service restart if connected; the existing
  coordinator validates/prepares the candidate before replacing the active
  configuration. The UI shows failure and retains its draft on rejection.

## Multiplexing

Auto means preserve subscription `multiplex`, not detect server support.
Without an explicit enabled block it is off. Xray Mux is not converted, and
XHTTP `xmux` is unrelated and untouched.

Local overrides are keyed by subscription ID and outbound tag, not name or
list position. They survive refresh only while that identity is retained.
Changed identities do not accidentally inherit another node's settings.
Only standalone VLESS/VMess/Trojan/Shadowsocks nodes without a flow or XHTTP
transport can be manually configured in this UI. This is deliberately
conservative; it is not a server capability assertion. Internal group members
are excluded using `ProxySelectionCatalog`, both in the picker and during
config application. Returning to Auto removes the override.

Manual mode replaces the mux block after a warning. It uses `max_streams`
only, never conflicting `max_connections`/`min_streams`. Inherited values
are shown read-only. Server support still has to be confirmed by the provider;
a successful native config check cannot prove remote compatibility.

## Verification

- `test/core_settings_test.dart`: defaults, bounds, inheritance, field scope,
  source-map safety, serialization, and shared native fixture.
- `test/app_settings_store_test.dart`: persistence and scoped reset.
- `test/singbox_config_cache_test.dart`: fingerprint invalidation and background
  build propagation.
- `test/settings_core_page_test.dart`: entry notice, draft/apply/failure,
  duplicate-submit guard, reset, narrow layout and inherited mux controls.
- `etonify-core/experimental/libbox/etonify_core_settings_test.go` validates
  the same fixture outputs with libbox CheckConfig. It does not open a VPN.
- `settings_core_previews.dart` provides isolated narrow/dark UI previews.

Before release, test Apply/reset while connected and disconnected, Wi-Fi to
cellular fallback on a real Android device, and a known compatible mux server.
Do not use a config-only test to claim mobile handover or remote mux support.

References:
- https://sing-box.sagernet.org/configuration/shared/dial/
- https://sing-box.sagernet.org/configuration/route/
- https://sing-box.sagernet.org/configuration/shared/udp-nat/
- https://sing-box.sagernet.org/configuration/shared/multiplex/
