#!/usr/bin/env python3
"""Pin Casks/multica-desktop.rb to the latest multica-ai/multica release.

Upstream publishes the macOS desktop app as one DMG per CPU architecture, and
the cask selects one per host. Both assets are immutable per release tag, so
both checksums move together with `version`.
"""

import re

from _common import (
    asset_sha256,
    fail,
    latest_tag,
    pinned_version,
    read,
    report,
    replace_sha_before_url,
    set_version_stanza,
    write,
)

REPO = "multica-ai/multica"
CASK = "Casks/multica-desktop.rb"
# One DMG per architecture; the cask URL interpolates `version`.
ASSET_SUFFIXES = ("mac-arm64.dmg", "mac-x64.dmg")

_TAG = re.compile(r"v(\d+(?:\.\d+)+)")


def main() -> None:
    tag = latest_tag(REPO)
    match = _TAG.fullmatch(tag)
    if not match:
        fail(f"{REPO} release tag {tag!r} is not v<version>; refusing to pin it")
    version = match.group(1)

    text = read(CASK)
    pinned = pinned_version(text, r'(?m)^\s*version "([^"]+)"$', CASK)
    if pinned == version:
        report("multica-desktop", pinned, version)
        return

    for suffix in ASSET_SUFFIXES:
        sha256 = asset_sha256(REPO, tag, f"multica-desktop-{version}-{suffix}")
        # The cask spells the URL with #{} interpolation, which is what the
        # checksum line above it has to be matched against.
        text = replace_sha_before_url(text, f"multica-desktop-#{{version}}-{suffix}", sha256, CASK)

    text = set_version_stanza(text, version, CASK)

    write(CASK, text)
    report("multica-desktop", pinned, version)


if __name__ == "__main__":
    main()
