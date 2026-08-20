# libbox binary

Etonify bundles
[`yamixdev/etonify-core`](https://github.com/yamixdev/etonify-core/tree/etonify-dev)
`v1.13.19-etonify.1`, based on the stable sing-box `v1.13.19` line. The AAR
exposes Etonify's versioned capability
contract, targeted and bounded asynchronous URLTest sessions with failover,
structured probe failures, bounded XHTTP/SplitHTTP transports, opt-in VLESS
Encryption, and resilient per-outbound external IP lookup.

`libbox.sha256` pins the exact AAR and is verified by CI before Android
compilation. `libbox.provenance.json` records the fork commit, upstream commit,
toolchain, Android API, and build tags used by the release workflow. Replacing
the binary requires updating both files and testing the Pigeon/Kotlin API
contract, Android unit tests, lint, assemble, upgrade from 0.2.1, and a device
soak test.
