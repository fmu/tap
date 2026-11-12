#!/usr/bin/env python3
"""Pin Formula/zed-remote-server.rb to the latest zed-industries/zed release.

Zed attaches one prebuilt remote-server binary per platform to every release.
All four POSIX assets are hashed together, so the keg never mixes versions, and
a tag that stops publishing one of them fails here instead of pinning a URL
that cannot be fetched. Windows builds exist but the tap is POSIX-only.
"""

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

REPO = "zed-industries/zed"
FORMULA = "Formula/zed-remote-server.rb"
ASSETS = (
    "zed-remote-server-macos-aarch64.gz",
    "zed-remote-server-macos-x86_64.gz",
    "zed-remote-server-linux-aarch64.gz",
    "zed-remote-server-linux-x86_64.gz",
)

# Zed's release tags are v<major>.<minor>.<patch>; a nightly or preview tag is
# never the "latest" release, so anything else means the API answered with
# something this pin does not understand.
_TAG = re.compile(r"v\d+(?:\.\d+)+")
_PIN = r"releases/download/v([^/\"]+)/zed-remote-server-"


def main() -> None:
    tag = latest_tag(REPO)
    if not _TAG.fullmatch(tag):
        fail(f"{REPO} release tag {tag!r} is not v<major>.<minor>...; refusing to pin it")
    version = version_from_tag(tag)

    text = read(FORMULA)
    pinned = pinned_version(text, _PIN, FORMULA)
    if pinned == version:
        report("zed-remote-server", pinned, version)
        return

    text, count = re.subn(r"releases/download/v[0-9][^/\"]+/", f"releases/download/{tag}/", text)
    if count != len(ASSETS):
        fail(f"{FORMULA}: expected {len(ASSETS)} versioned asset URLs, found {count}")

    for asset in ASSETS:
        sha256 = asset_sha256(REPO, tag, asset)
        text = replace_sha_after_url(text, asset, sha256, FORMULA)

    write(FORMULA, text)
    report("zed-remote-server", pinned, version)


if __name__ == "__main__":
    main()
