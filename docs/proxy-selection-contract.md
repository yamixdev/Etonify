# Proxy selection and subscription groups

`ProxySelectionCatalog` separates user choices from concrete core outbounds.

- Subscription groups are managed URLTest routes. Their members remain in the generated config, but are not independent root-selector or global-lowest candidates.
- Membership is derived from resolved group references, never from `cand`, `proxy`, country names or other naming patterns. Unrelated standalone nodes with those names remain selectable.
- A group with one surviving member remains a group. A subscription with one group selects it directly; global `lowest` is only needed for multiple user choices.
- Old saved selections of a member resolve to its group. The same resolution is used by import/persistence, runtime selection validation and the config builder.
- Internal child tags remain available for latency events and IP attribution. They are not shown as user-facing group names or selectable child rows.
- Xray `fallbackTag` is resolved by exact tag within its source profile and stored separately as `fallback_outbounds`. These nodes remain in the runtime config but are excluded from user choices and global-lowest candidates, even if their group's primaries become unusable. Never add them to the ordinary URLTest member list just to hide them.
- This preserves fallback ownership, not Xray balancing semantics: sing-box URLTest has no `fallbackTag`, `leastLoad` cost policy or equivalent reserved-fallback option. Automatic Xray-style fallback execution is not implemented by this UI/import fix.
- Active server identity comes from core selection events. A smaller measured latency is not evidence that the core switched to that node.

Manual URLTest uses root `select`, even if a provider group is currently selected. Otherwise a whole-subscription UI session can wait for nodes outside the tested group. The core refreshes nested selections children-first without rerunning probes or replacing the user's root selection.

A missing result is not a measured failure: the dash means no completed result; a red warning represents a reported error or an elapsed probe timeout. Cancelling a session does not prove untested nodes are offline.

Xray import accepts both flat VLESS `settings.address/port/id` and legacy `vnext/users`. Raw TCP has no sing-box transport object. Existing imported payloads need a subscription refresh or reparse to recover previously skipped nodes.

Existing exports/payloads created before fallback ownership was stored also need a refresh or reparse from saved raw content. Do not infer ownership from names when the raw content is missing. An optional local regression check uses `ETONIFY_TEST_PROFILE`; private profile content must never be committed as a fixture.

Regression coverage: `subscription_parser_test`, `proxy_selection_catalog_test`, `proxy_group_test`, `latency_coordinator_test`, `performance_widgets_test`, and core `TestRefreshURLTestSelectionsChildrenBeforeParents`.

References: [Xray VLESS](https://xtls.github.io/en/config/outbounds/vless.html), [sing-box URLTest](https://sing-box.sagernet.org/configuration/outbound/urltest/).
