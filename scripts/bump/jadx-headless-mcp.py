#!/usr/bin/env python3
"""Pin Formula/jadx-headless-mcp.rb to the latest upstream release.

The versioned Formula/jadx-headless-mcp@<release>.rb is the release REA verifies
and is pinned by `scripts/bump/rea.py`; this unversioned formula tracks upstream's
latest release for standalone use.
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

REPO = "1013503897/jadx-headless-mcp"
FORMULA = "Formula/jadx-headless-mcp.rb"

_PIN = r'jadx-headless-mcp-([^/"]+)-all\.jar'


def main() -> None:
    tag = os.environ.get("RELEASE_TAG", "").strip() or latest_tag(REPO)
    if not tag.startswith("v"):
        tag = f"v{tag.lstrip('v')}"
    version = version_from_tag(tag)

    text = read(FORMULA)
    pinned = pinned_version(text, _PIN, FORMULA)
    if pinned == version:
        report("jadx-headless-mcp", pinned, version)
        return

    asset = f"jadx-headless-mcp-{version}-all.jar"
    sha256 = asset_sha256(REPO, tag, asset)

    text, count = re.subn(
        r"https://github\.com/"
        + re.escape(REPO)
        + r"/releases/download/v[^\"/]+/jadx-headless-mcp-[^\"/]+-all\.jar",
        f"https://github.com/{REPO}/releases/download/{tag}/{asset}",
        text,
    )
    if count != 1:
        fail(f"{FORMULA}: expected one release JAR URL, found {count}")
    text = replace_sha_after_url(text, asset, sha256, FORMULA)

    write(FORMULA, text)
    report("jadx-headless-mcp", pinned, version)


if __name__ == "__main__":
    main()
