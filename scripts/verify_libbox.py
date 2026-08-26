#!/usr/bin/env python3
"""Verify that the bundled libbox artifacts match their recorded source."""

from __future__ import annotations

import hashlib
import json
import re
import subprocess
import sys
import zipfile
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
LIBS = ROOT / "android" / "app" / "libs"
AAR = LIBS / "libbox.aar"
SOURCES = LIBS / "libbox-sources.jar"
HASH_FILE = LIBS / "libbox.sha256"
PROVENANCE_FILE = LIBS / "libbox.provenance.json"
CORE_PATH = ROOT / "etonify-core"

# Generated gomobile interfaces are compile-time contracts implemented by the
# Android Kotlin bridge. Pin the normalized signatures that require explicit
# client adaptation. A future core update that adds an abstract callback or
# changes TUN/setup options will fail here before an APK build is attempted.
LIBBOX_ANDROID_API_ENTRIES = (
    "io/nekohasekai/libbox/PlatformInterface.java",
    "io/nekohasekai/libbox/CommandServerHandler.java",
    "io/nekohasekai/libbox/CommandClientHandler.java",
    "io/nekohasekai/libbox/TunOptions.java",
    "io/nekohasekai/libbox/SetupOptions.java",
)
LIBBOX_ANDROID_API_SHA256 = (
    "8023c3f48dcfe1870edcaff66fdb3bcd72c5f027232e630920fca393666510fa"
)


def fail(message: str) -> None:
    raise RuntimeError(message)


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest()


def git(*args: str, cwd: Path = ROOT) -> str:
    return subprocess.check_output(
        ["git", *args],
        cwd=cwd,
        text=True,
        stderr=subprocess.STDOUT,
    ).strip()


def tracked_gitlink_commit() -> str:
    line = git("ls-files", "--stage", "--", "etonify-core")
    match = re.fullmatch(r"160000 ([0-9a-f]{40}) 0\tetonify-core", line)
    if match is None:
        fail("etonify-core must be tracked as a git submodule")
    return match.group(1)


def normalized_android_api(archive: zipfile.ZipFile) -> bytes:
    signatures: list[str] = []
    for entry_name in LIBBOX_ANDROID_API_ENTRIES:
        try:
            source = archive.read(entry_name).decode("utf-8")
        except KeyError as error:
            fail(f"libbox sources archive is missing {entry_name}")
            raise AssertionError("unreachable") from error
        signatures.append(f"[{entry_name}]")
        for line in source.splitlines():
            normalized = " ".join(line.strip().split())
            if (
                normalized.startswith("public ")
                and "(" in normalized
                and normalized.endswith(";")
            ):
                signatures.append(normalized)
    return ("\n".join(signatures) + "\n").encode("utf-8")


def verify_android_api_contract() -> str:
    with zipfile.ZipFile(SOURCES) as archive:
        normalized = normalized_android_api(archive)
    actual = hashlib.sha256(normalized).hexdigest()
    if actual != LIBBOX_ANDROID_API_SHA256:
        fail(
            "libbox Android Java API changed: adapt the Kotlin bridge and "
            "update LIBBOX_ANDROID_API_SHA256; "
            f"expected {LIBBOX_ANDROID_API_SHA256}, got {actual}"
        )
    return actual


def main() -> None:
    required = (AAR, SOURCES, HASH_FILE, PROVENANCE_FILE)
    missing = [str(path.relative_to(ROOT)) for path in required if not path.is_file()]
    if missing:
        fail(f"missing libbox artifacts: {', '.join(missing)}")
    if AAR.stat().st_size == 0 or SOURCES.stat().st_size == 0:
        fail("libbox binary and sources archive must not be empty")

    android_api_hash = verify_android_api_contract()

    hash_line = HASH_FILE.read_text(encoding="utf-8").strip()
    hash_match = re.fullmatch(r"([0-9a-fA-F]{64})\s+\*?libbox\.aar", hash_line)
    if hash_match is None:
        fail("libbox.sha256 must contain one SHA-256 entry for libbox.aar")
    pinned_hash = hash_match.group(1).lower()
    actual_hash = sha256(AAR)
    if actual_hash != pinned_hash:
        fail(f"libbox.aar SHA-256 mismatch: expected {pinned_hash}, got {actual_hash}")

    provenance = json.loads(PROVENANCE_FILE.read_text(encoding="utf-8"))
    if provenance.get("artifact") != "libbox.aar":
        fail("libbox provenance has an unexpected artifact name")
    if str(provenance.get("sha256", "")).lower() != actual_hash:
        fail("libbox provenance SHA-256 does not match the bundled AAR")

    source_commit = str(provenance.get("source_commit", "")).lower()
    if re.fullmatch(r"[0-9a-f]{40}", source_commit) is None:
        fail("libbox provenance source_commit must be a full Git commit")
    gitlink_commit = tracked_gitlink_commit()
    if source_commit != gitlink_commit:
        fail(
            "libbox provenance source_commit does not match the etonify-core "
            f"gitlink: {source_commit} != {gitlink_commit}"
        )

    if (CORE_PATH / ".git").exists():
        checkout_commit = git("rev-parse", "HEAD", cwd=CORE_PATH).lower()
        if checkout_commit != source_commit:
            fail(
                "checked-out etonify-core commit does not match libbox provenance: "
                f"{checkout_commit} != {source_commit}"
            )

    for key in (
        "etonify_version",
        "upstream_commit",
        "go",
        "android_ndk",
        "build_tags",
    ):
        if not provenance.get(key):
            fail(f"libbox provenance is missing {key}")

    expected_abis = {"armeabi-v7a", "arm64-v8a"}
    recorded_abis = set(provenance.get("android_abis", ()))
    if recorded_abis != expected_abis:
        fail(
            "libbox provenance Android ABIs must be exactly "
            f"{sorted(expected_abis)}, got {sorted(recorded_abis)}"
        )
    with zipfile.ZipFile(AAR) as archive:
        bundled_abis = {
            name.split("/")[1]
            for name in archive.namelist()
            if re.fullmatch(r"jni/[^/]+/libbox\.so", name)
        }
    if bundled_abis != expected_abis:
        fail(
            "libbox.aar Android ABIs must be exactly "
            f"{sorted(expected_abis)}, got {sorted(bundled_abis)}"
        )

    print(
        "Verified libbox.aar "
        f"sha256={actual_hash} source_commit={source_commit} "
        f"android_api={android_api_hash}"
    )


if __name__ == "__main__":
    try:
        main()
    except (OSError, subprocess.CalledProcessError, ValueError, RuntimeError) as error:
        print(f"libbox verification failed: {error}", file=sys.stderr)
        raise SystemExit(1) from error
