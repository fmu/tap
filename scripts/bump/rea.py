#!/usr/bin/env python3
"""Pin Formula/rea.rb and the engine formulae REA verifies to one REA release.

REA is the authority for its whole version set. Each release verifies exactly
one JADX headless MCP, one Kuna and one Ghidra build, and reports every other
build as unverified, so these packages are bumped together instead of tracking
their own upstream latest:

  Formula/rea.rb                rea-agents npm tarball
  Formula/jadx-headless-mcp.rb  src/android/JadxRelease.ts     JADX_RELEASE.version
  Formula/kuna.rb               src/kuna/KunaRelease.ts        KUNA_VERIFIED_VERSION
  Formula/ghidra@12.1.rb        src/ghidra/GhidraReleasePolicy.ts
                                                             SUPPORTED_GHIDRA_VERSION

The pins are read from the released tag's source, not from upstream's main
branch, so an unpublished commit that already moved Kuna to a newer release
cannot make the tap advertise a combination REA never shipped.

The Ghidra pin is checked but never rewritten. Moving it means a new Ghidra keg
and a GhidraMCP extension built for that exact release (see
`scripts/bump/ghidra-mcp.py`), which is a human decision; the bump fails loudly
instead of publishing a tap whose parts disagree.

Versions live in the URLs, not in `version` stanzas: Homebrew scans them from
the asset names and `brew audit --strict` rejects a redundant stanza.

Usage:
  python3 scripts/bump/rea.py            # pin the latest REA release
  python3 scripts/bump/rea.py --check    # verify the current pins, write nothing

`--check` is what CI runs: it never touches the npm registry and exits non-zero
when the formulae no longer agree with the REA release they name. The bump
honours RELEASE_TAG like the other scripts in this directory.
"""

from __future__ import annotations

import re
import sys

from _common import (
    asset_sha256,
    download_sha256,
    fail,
    latest_tag,
    pinned_version,
    raw_file,
    read,
    report,
    replace_sha_after_url,
    write,
)

REPO = "morluto/rea"
TAG_PREFIX = "rea-agents-"
NPM_TARBALL = "https://registry.npmjs.org/rea-agents/-/rea-agents-{version}.tgz"

REA_FORMULA = "Formula/rea.rb"
JADX_FORMULA = "Formula/jadx-headless-mcp.rb"
KUNA_FORMULA = "Formula/kuna.rb"
GHIDRA_FORMULA = "Formula/ghidra@12.1.rb"

JADX_REPO = "1013503897/jadx-headless-mcp"
JADX_SOURCE = "src/android/JadxRelease.ts"
KUNA_REPO = "Noelo-Lab/kuna"
KUNA_SOURCE = "src/kuna/KunaRelease.ts"
GHIDRA_SOURCE = "src/ghidra/GhidraReleasePolicy.ts"

KUNA_PLATFORMS = ("macos-arm64", "macos-x86_64", "linux-x86_64", "linux-arm64")


def _version_from_tag(tag: str) -> str:
    """REA tags name the npm package: `rea-agents-6.8.0`."""
    match = re.fullmatch(re.escape(TAG_PREFIX) + r"(\d+(?:\.\d+)+(?:[-+][0-9A-Za-z.-]+)?)", tag)
    if not match:
        fail(f"{REPO}: unexpected release tag {tag!r}; expected {TAG_PREFIX}<version>")
    return match.group(1)


def _tag_for_version(version: str) -> str:
    return f"{TAG_PREFIX}{version}"


def _engine_pins(tag: str) -> dict[str, str]:
    """Read the three engine releases a REA tag verifies."""
    jadx_source = raw_file(REPO, tag, JADX_SOURCE)
    kuna_source = raw_file(REPO, tag, KUNA_SOURCE)
    ghidra_source = raw_file(REPO, tag, GHIDRA_SOURCE)

    match = re.search(r"JADX_RELEASE\s*=\s*Object\.freeze\(\{\s*version:\s*\"([^\"]+)\"", jadx_source)
    if not match:
        fail(f"{JADX_SOURCE} at {tag}: could not find JADX_RELEASE.version")
    jadx = match.group(1)

    match = re.search(r'KUNA_VERIFIED_VERSION\s*=\s*"([^"]+)"', kuna_source)
    if not match:
        fail(f"{KUNA_SOURCE} at {tag}: could not find KUNA_VERIFIED_VERSION")
    kuna = match.group(1)

    match = re.search(r'SUPPORTED_GHIDRA_VERSION\s*=\s*"([^"]+)"', ghidra_source)
    if not match:
        fail(f"{GHIDRA_SOURCE} at {tag}: could not find SUPPORTED_GHIDRA_VERSION")
    ghidra = match.group(1)

    return {"jadx-headless-mcp": jadx, "kuna": kuna, "ghidra": ghidra}


def _rea_pin() -> str:
    return pinned_version(
        read(REA_FORMULA),
        r'registry\.npmjs\.org/rea-agents/-/rea-agents-([^"]+)\.tgz',
        REA_FORMULA,
    )


def _jadx_pin() -> str:
    return pinned_version(
        read(JADX_FORMULA),
        r'jadx-headless-mcp-([^/"]+)-all\.jar',
        JADX_FORMULA,
    )


def _kuna_pin() -> str:
    return pinned_version(
        read(KUNA_FORMULA),
        r'kuna-v([^/"]+)-macos-arm64\.tar\.gz',
        KUNA_FORMULA,
    )


def _ghidra_pin() -> str:
    return pinned_version(read(GHIDRA_FORMULA), r'(?m)^\s*version "([^"]+)"$', GHIDRA_FORMULA)


def pin_rea(version: str) -> None:
    text = read(REA_FORMULA)
    text, count = re.subn(
        r"https://registry\.npmjs\.org/rea-agents/-/rea-agents-[^\"]+\.tgz",
        NPM_TARBALL.format(version=version),
        text,
    )
    if count != 1:
        fail(f"{REA_FORMULA}: expected one npm tarball URL, found {count}")
    sha256 = download_sha256(NPM_TARBALL.format(version=version))
    text = replace_sha_after_url(text, f"rea-agents-{version}.tgz", sha256, REA_FORMULA)
    write(REA_FORMULA, text)


def pin_jadx(version: str) -> None:
    text = read(JADX_FORMULA)
    text, count = re.subn(
        r"https://github\.com/"
        + re.escape(JADX_REPO)
        + r"/releases/download/v[^\"/]+/jadx-headless-mcp-[^\"/]+-all\.jar",
        f"https://github.com/{JADX_REPO}/releases/download/v{version}/"
        f"jadx-headless-mcp-{version}-all.jar",
        text,
    )
    if count != 1:
        fail(f"{JADX_FORMULA}: expected one release JAR URL, found {count}")
    sha256 = asset_sha256(JADX_REPO, f"v{version}", f"jadx-headless-mcp-{version}-all.jar")
    text = replace_sha_after_url(
        text, f"jadx-headless-mcp-{version}-all.jar", sha256, JADX_FORMULA
    )
    write(JADX_FORMULA, text)


def pin_kuna(version: str) -> None:
    text = read(KUNA_FORMULA)
    for platform in KUNA_PLATFORMS:
        asset = f"kuna-v{version}-{platform}.tar.gz"
        text, count = re.subn(
            r"https://github\.com/"
            + re.escape(KUNA_REPO)
            + r"/releases/download/v[^\"/]+/kuna-v[^\"/]+-"
            + re.escape(platform)
            + r"\.tar\.gz",
            f"https://github.com/{KUNA_REPO}/releases/download/v{version}/{asset}",
            text,
        )
        if count != 1:
            fail(f"{KUNA_FORMULA}: expected one {platform} URL, found {count}")
        sha256 = asset_sha256(KUNA_REPO, f"v{version}", asset)
        text = replace_sha_after_url(text, asset, sha256, KUNA_FORMULA)
    write(KUNA_FORMULA, text)


def _check_pins(rea_version: str, pins: dict[str, str]) -> bool:
    """Compare the tap's engine pins with the ones a REA release verifies."""
    rows = (
        ("rea", rea_version, rea_version),
        ("jadx-headless-mcp", _jadx_pin(), pins["jadx-headless-mcp"]),
        ("kuna", _kuna_pin(), pins["kuna"]),
        ("ghidra", _ghidra_pin(), pins["ghidra"]),
    )
    agreed = True
    for package, pinned, verified in rows:
        if pinned == verified:
            print(f"{package}: {pinned} (matches REA {rea_version})")
            continue
        agreed = False
        print(f"{package}: {pinned} but REA {rea_version} verifies {verified}")
    return agreed


def check() -> None:
    rea_version = _rea_pin()
    pins = _engine_pins(_tag_for_version(rea_version))
    if _check_pins(rea_version, pins):
        return
    fail(
        "the tap no longer matches the engines REA verifies; run "
        "`python3 scripts/bump/rea.py` to re-pin jadx-headless-mcp and kuna "
        "with rea, and update the Ghidra keg (plus ghidra-mcp) by hand when "
        "REA's verified Ghidra release moves"
    )


def main() -> None:
    tag = latest_tag(REPO)
    if not tag.startswith(TAG_PREFIX):
        tag = _tag_for_version(tag.lstrip("v"))
    version = _version_from_tag(tag)
    pins = _engine_pins(tag)

    current_rea = _rea_pin()
    current_jadx = _jadx_pin()
    current_kuna = _kuna_pin()
    current_ghidra = _ghidra_pin()

    # Fail before writing anything: a Ghidra move also needs a new Ghidra keg
    # and a matching GhidraMCP build, which this script cannot produce.
    if current_ghidra != pins["ghidra"]:
        fail(
            f"REA {version} verifies Ghidra {pins['ghidra']}, but the tap pins "
            f"{current_ghidra} in {GHIDRA_FORMULA}. Update the Ghidra keg and "
            f"Formula/ghidra-mcp.rb by hand (a Ghidra release needs its own native "
            f"build and an extension built for it), then re-run this bump."
        )

    if current_jadx != pins["jadx-headless-mcp"]:
        pin_jadx(pins["jadx-headless-mcp"])
    report("jadx-headless-mcp", current_jadx, pins["jadx-headless-mcp"])

    if current_kuna != pins["kuna"]:
        pin_kuna(pins["kuna"])
    report("kuna", current_kuna, pins["kuna"])

    if current_rea != version:
        pin_rea(version)
    report("rea", current_rea, version)

    if not _check_pins(version, pins):
        fail("the re-pinned formulae still disagree with the REA release")


if __name__ == "__main__":
    if "--check" in sys.argv[1:]:
        check()
    else:
        main()
