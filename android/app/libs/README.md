# libbox binary

Etonify bundles
[`yamixdev/etonify-core`](https://github.com/yamixdev/etonify-core/tree/etonify-dev)
`v1.15.0-alpha.3-etonify.1`, based on the prerelease sing-box
`v1.15.0-alpha.3` tag. The AAR
exposes Etonify's versioned capability
contract, targeted and bounded asynchronous URLTest sessions with failover,
structured probe failures, bounded XHTTP/SplitHTTP transports, opt-in VLESS
Encryption, resilient per-outbound external IP lookup, and bounded HTTP fetches
through the selected outbound. The new sing-tun TCP/IP stack is the default;
the legacy system, gVisor and mixed stacks remain available as compatibility
modes. WireGuard is not included in the Android build.

`libbox.sha256` pins the exact AAR and is verified by CI before Android
compilation. `libbox.provenance.json` records the fork commit, upstream commit,
toolchain, Android API, and build tags used by the release workflow. Replacing
the binary requires updating both files and testing the Pigeon/Kotlin API
contract, Android unit tests, lint, assemble, upgrade from the previous release, and a device
soak test.
