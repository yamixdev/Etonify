# Subscription HWID sharing

General settings offers an explicit, default-off "Send HWID to providers" switch.
It applies at request time to ordinary HTTPS subscriptions and Happ imports,
including manual and scheduled refresh. It does not trigger a refresh itself.
Per-subscription permissions continue to work when the global switch is off.
Global consent is stored locally and excluded from imported/exported settings.

The common subscription fetcher sends `X-HWID`, `X-Device-Os`, `X-Ver-Os` and
`X-Device-Model` when available, along with the existing User-Agent. The Android
identity is the existing app-scoped Android ID; enabling this switch does not
rotate it. No random ID is generated per request. A custom per-subscription ID
still takes precedence. IDs must match `[a-zA-Z0-9=-]{10,64}`; failure is reported
without logging the ID. Locale and extra hardware details are not added.

No identity headers are added to unrelated geo-resource, OTA or URLTest requests.
Existing HTTPS requirements and cross-origin redirect header stripping remain
unchanged. Explicit custom request headers remain user-controlled.

When global consent is enabled, Happ imports do not ask for HWID consent again.
Deep-link import still requires confirmation to add the subscription. Skipping
the HWID prompt must not store global consent as a permanent per-subscription
permission, so switching the global setting off remains meaningful.

Device listing and names in a provider's bot depend on the server-side panel;
sending headers cannot guarantee that the bot implements that feature. Device
identity is not guaranteed to match another client or survive clearing app data.

Source: [Remnawave HWID device limit](https://docs.rw/features/hwid-device-limit/).
