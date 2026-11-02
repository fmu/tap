#!/usr/bin/env python3
"""Pin Formula/partclone.rb to the latest Thomas-Tsai/partclone release.

partclone publishes plain version tags and no release assets, so the formula
builds the tagged source; the version comes from the tag and the checksum is the
SHA-256 of that tag's source archive.
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
    version_from_tag,
    write,
)

REPO = "Thomas-Tsai/partclone"
FORMULA = "Formula/partclone.rb"

_TAG = re.compile(r"v?\d+(?:\.\d+)+")
_PIN = r"partclone/archive/refs/tags/([^/\"]+)\.tar\.gz"


def main() -> None:
    tag = latest_tag(REPO)
    if not _TAG.fullmatch(tag):
        fail(f"{REPO}: release tag {tag!r} is not a version; refusing to pin it")
    version = version_from_tag(tag)

    text = read(FORMULA)
    pinned = pinned_version(text, _PIN, FORMULA)
    if pinned == version:
        report("partclone", pinned, version)
        return

    url = f"https://github.com/{REPO}/archive/refs/tags/{tag}.tar.gz"
    sha256 = download_sha256(url)

    text, count = re.subn(
        r"https://github\.com/Thomas-Tsai/partclone/archive/refs/tags/[^\"]+\.tar\.gz",
        url,
        text,
    )
    if count != 1:
        fail(f"{FORMULA}: expected one tagged source archive URL, found {count}")
    text = replace_sha_after_url(text, f"{tag}.tar.gz", sha256, FORMULA)

    write(FORMULA, text)
    report("partclone", pinned, version)


if __name__ == "__main__":
    main()
