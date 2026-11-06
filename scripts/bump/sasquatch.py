#!/usr/bin/env python3
"""Pin Formula/sasquatch.rb to the latest onekey-sec/sasquatch release.

sasquatch tags its squashfs-tools fork as
`sasquatch-v<squashfs-version>-<revision>`, and publishes Debian packages for
Linux only. The formula builds the tagged source itself, so the version comes
from the tag and the checksum is the SHA-256 of that tag's source archive.
"""

import re

from _common import (
    download_sha256,
    drop_bottle_block,
    fail,
    latest_tag,
    pinned_version,
    read,
    report,
    set_version_stanza,
    write,
)

REPO = "onekey-sec/sasquatch"
FORMULA = "Formula/sasquatch.rb"
TAG_PREFIX = "sasquatch-v"

_PIN = r"sasquatch/archive/refs/tags/sasquatch-v([^/\"]+)\.tar\.gz"


def main() -> None:
    tag = latest_tag(REPO)
    if not tag.startswith(TAG_PREFIX):
        fail(f"{REPO}: unexpected release tag {tag!r}; expected {TAG_PREFIX}<version>")
    version = tag[len(TAG_PREFIX):]

    text = read(FORMULA)
    pinned = pinned_version(text, _PIN, FORMULA)
    if pinned == version:
        report("sasquatch", pinned, version)
        return

    url = f"https://github.com/{REPO}/archive/refs/tags/{tag}.tar.gz"
    sha256 = download_sha256(url)

    text, count = re.subn(
        r"https://github\.com/onekey-sec/sasquatch/archive/refs/tags/[^\"]+\.tar\.gz",
        url,
        text,
    )
    if count != 1:
        fail(f"{FORMULA}: expected one tagged source archive URL, found {count}")
    # Homebrew would read the version from the tag as "6", so the formula pins
    # the release tag explicitly. That `version` line sits between the `url` and
    # the `sha256`, so `replace_sha_after_url` (which expects them adjacent)
    # cannot be used here.
    text, count = re.subn(
        r'(  url "[^"\n]*\.tar\.gz"\n  version "[^"]+"\n  sha256 ")([0-9a-f]{64})(")',
        lambda match: match.group(1) + sha256 + match.group(3),
        text,
    )
    if count != 1:
        fail(f"{FORMULA}: expected one sha256 after the version stanza, found {count}")
    text = set_version_stanza(text, version, FORMULA)
    text = drop_bottle_block(text, FORMULA)

    write(FORMULA, text)
    report("sasquatch", pinned, version)


if __name__ == "__main__":
    main()
