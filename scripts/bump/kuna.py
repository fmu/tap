#!/usr/bin/env python3
"""Pin Formula/kuna.rb to the latest upstream release.

The versioned Formula/kuna@<release>.rb is the release REA verifies and is pinned
by `scripts/bump/rea.py`; this unversioned formula tracks upstream's latest
release for standalone use.
"""

import os
import re

from _common import (
    asset_sha256,
    fail,
    latest_tag,
    pinned_version,
    read,
    replace_sha_after_url,
    report,
    version_from_tag,
    write,
)

REPO = "Noelo-Lab/kuna"
FORMULA = "Formula/kuna.rb"
PLATFORMS = ("macos-arm64", "macos-x86_64", "linux-x86_64", "linux-arm64")

_PIN = r'kuna-v([^/"]+)-macos-arm64\.tar\.gz'


def main() -> None:
    tag = os.environ.get("RELEASE_TAG", "").strip() or latest_tag(REPO)
    if not tag.startswith("v"):
        tag = f"v{tag.lstrip('v')}"
    version = version_from_tag(tag)

    text = read(FORMULA)
    pinned = pinned_version(text, _PIN, FORMULA)
    if pinned == version:
        report("kuna", pinned, version)
        return

    assets = {platform: f"kuna-v{version}-{platform}.tar.gz" for platform in PLATFORMS}
    shas = {platform: asset_sha256(REPO, tag, asset) for platform, asset in assets.items()}

    for platform, asset in assets.items():
        text, count = re.subn(
            r"https://github\.com/"
            + re.escape(REPO)
            + r"/releases/download/v[^\"/]+/kuna-v[^\"/]+-"
            + re.escape(platform)
            + r"\.tar\.gz",
            f"https://github.com/{REPO}/releases/download/{tag}/{asset}",
            text,
        )
        if count != 1:
            fail(f"{FORMULA}: expected one {platform} URL, found {count}")
        text = replace_sha_after_url(text, asset, shas[platform], FORMULA)

    write(FORMULA, text)
    report("kuna", pinned, version)


if __name__ == "__main__":
    main()
