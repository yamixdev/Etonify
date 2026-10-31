# Optional Android root module

Experimental, Android 8+ and arm64-v8a only. Real-device routing and SELinux verification is still required. This is a userspace component, not a kernel `.ko` or a required Magisk module.

The APK does not contain the executable. Settings → Root mode provides explicit authorization, signed download/update and removal. Ordinary VPN does not start a root process or poll for root. The mode preference applies to the next connection; there is no automatic fallback to an unprotected connection on root startup failure.

## Release setup

1. Create an RSA3072 signing key **outside the repository**, keep a protected backup, and store the PEM private key in GitHub Actions secret `ROOT_MODULE_SIGNING_KEY`. Never commit it.
2. Set repository variable `ROOT_MODULE_PUBLIC_KEY` to the base64-encoded DER/SPKI public key. The Android release workflow embeds this trust key; an APK built without it deliberately cannot install modules.
3. Commit/push changes in order: `third_party/sing-tun`, `etonify-core` and its TUN gitlink, then the client and its core gitlink. The workflow uses these pinned revisions, not the newest remote branch.
4. Run **Root module release** with an independent semantic version and monotonically increasing version code. It builds only the standalone arm64 module on GitHub, not an APK. Signing fails if the public and private keys do not match.
5. Draft releases are not available to the in-app downloader. For device testing, publish an explicitly experimental prerelease containing `etonify-root-arm64-v8a.zip`. Publish a matching-key APK separately. Do not describe this mode as device-verified until the checks below pass.

The downloader discovers published `root-module-vX.Y.Z` releases in this repository, excludes unrelated APK releases, verifies the signature of the exact manifest bytes and then the binary hash, ABI, protocol and minimum client build. Root-owned staging is hashed again before execution. Installation keeps the previous version for transactional rollback; arbitrary downgrades are rejected. Process death between native activation and app metadata commit fails closed and may require explicit reinstallation.

## Runtime boundaries

The daemon uses an authenticated, app-UID-only local Unix socket. It does not expose a root shell or a TCP management API. Android's foreground service owns a pipe lease: Stop or process death closes it, and the daemon tears down its own resources. Startup and cleanup use a process lock; recovery uses a root-owned ownership journal. It never flushes the device's entire firewall or route rules.

The device DNS option becomes the actual physical network's numeric resolver, not a substituted public provider. Explicit protected DNS remains protected. Physical DNS changes are event-driven. This initial version rejects unsupported settings instead of silently bypassing them, including package split routing, extra proxy listeners, SSH/Tor and Shadowsocks plugins. Supported root configuration is intentionally narrower than all possible sing-box features.

## Device checks before general release

- Non-root, denied permission, canceled prompt: no tunnel or rules created.
- Start → Stop during authorization; repeated Start/Stop; stop from tile and notification; reopen the client after each.
- TCP, UDP, DNS, IPv4/IPv6, Wi-Fi ↔ mobile and DNS-only changes; screen off/background.
- Kill UI process and daemon separately; verify cleanup and explicit recovery without automatic restart loops.
- Install/update/remove, corrupt archive, wrong signature/ABI and interrupted update; previous installation remains recoverable.
- Coexistence with other VPN/firewall rules; only Etonify resources may be removed.
- Test hotspot/repeater forwarding separately before claiming support on a particular firmware.

Local verification may run Flutter/JVM/Go tests and `python -B root-module/package_test.py`; Android core binaries and APKs are built on GitHub only.
