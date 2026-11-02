#!/usr/bin/env python3
"""Pin Formula/skippy.rb to the newest release that ships a Skippy CLI.

Upstream's stable tags carry no standalone Skippy CLI; the CLI is attached to
the rolling-preview releases instead. This script scans releases newest first
(prereleases included) and pins the first one with the macOS arm64 CLI asset.
"""

import os
import re

from _common import (
    asset_sha256,
    fail,
    pinned_version,
    read,
    releases,
    report,
    set_version_stanza,
    version_from_tag,
    write,
)

REPO = "Mesh-LLM/mesh-llm"
FORMULA = "Formula/skippy.rb"
ASSET_NAME = re.compile(r"^skippy-v(?P<version>.+)-darwin-aarch64-cli\.tar\.gz$")
PIN = r"skippy-v([^/\"]+)-darwin-aarch64-cli\.tar\.gz"


def _release_with_cli() -> tuple[str, str]:
    """Return (tag, asset) for the newest release that publishes the CLI."""
    forced = os.environ.get("RELEASE_TAG", "").strip()
    if forced:
        version = version_from_tag(forced)
        return forced, f"skippy-v{version}-darwin-aarch64-cli.tar.gz"

    for release in releases(REPO):
        for asset in release.get("assets", []):
            name = asset.get("name", "")
            if ASSET_NAME.fullmatch(name):
                return release["tag_name"], name

    fail(f"{REPO}: no release publishes a macOS arm64 Skippy CLI asset")


def main() -> None:
    tag, asset = _release_with_cli()
    version = ASSET_NAME.fullmatch(asset).group("version")

    text = read(FORMULA)
    pinned = pinned_version(text, PIN, FORMULA)
    if pinned == version:
        report("skippy", pinned, version)
        return

    sha256 = asset_sha256(REPO, tag, asset)

    text, count = re.subn(
        r"https://github\.com/Mesh-LLM/mesh-llm/releases/download/[^\"]+/"
        r"skippy-[^\"]+-darwin-aarch64-cli\.tar\.gz",
        f"https://github.com/{REPO}/releases/download/{tag}/{asset}",
        text,
    )
    if count != 1:
        fail(f"{FORMULA}: expected one Skippy CLI URL, found {count}")
    text = set_version_stanza(text, version, FORMULA)
    # The checksum follows the version stanza, which sits between url and sha256.
    text, count = re.subn(
        r'(?m)(^  version "[^"]+"\n  sha256 ")([0-9a-f]{64})(")',
        lambda match: match.group(1) + sha256 + match.group(3),
        text,
    )
    if count != 1:
        fail(f"{FORMULA}: expected one sha256 after the version stanza, found {count}")

    write(FORMULA, text)
    report("skippy", pinned, version)


if __name__ == "__main__":
    main()
