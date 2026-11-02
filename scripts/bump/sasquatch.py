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
    fail,
    latest_tag,
    pinned_version,
    read,
    replace_sha_after_url,
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
    # the release tag explicitly.
    text = set_version_stanza(text, version, FORMULA)
    text = replace_sha_after_url(text, f"{tag}.tar.gz", sha256, FORMULA)

    write(FORMULA, text)
    report("sasquatch", pinned, version)


if __name__ == "__main__":
    main()
