#!/usr/bin/env python3
"""Pin Formula/safari-ext-dearrow.rb to the latest DeArrow release.

The formula builds its Safari app from the `SafariExtension.zip` asset that
upstream's release workflow attaches to every published release, so the version
comes from the release tag and the checksum is the SHA-256 of that asset. The
tag has no `v` prefix; a release published without the Safari build fails here
instead of pinning an asset nobody can fetch.
"""

import re

from _common import (
    asset_sha256,
    fail,
    latest_tag,
    pinned_version,
    read,
    report,
    replace_sha_after_url,
    version_from_tag,
    write,
)

REPO = "ajayyy/DeArrow"
FORMULA = "Formula/safari-ext-dearrow.rb"
ASSET = "SafariExtension.zip"

# DeArrow tags are plain dotted versions (2.3.10). Anything else, such as a
# scratch tag, is not a release this formula can pin.
_TAG = re.compile(r"\d+(?:\.\d+)+")
_PIN = r"releases/download/([^/\"]+)/SafariExtension\.zip"


def main() -> None:
    tag = latest_tag(REPO)
    if not _TAG.fullmatch(tag):
        fail(f"{REPO} release tag {tag!r} is not <major>.<minor>[.<patch>]; refusing to pin it")
    version = version_from_tag(tag)

    text = read(FORMULA)
    pinned = pinned_version(text, _PIN, FORMULA)
    if pinned == version:
        report("safari-ext-dearrow", pinned, version)
        return

    sha256 = asset_sha256(REPO, tag, ASSET)

    text, count = re.subn(
        r"releases/download/[^/\"]+/SafariExtension\.zip",
        f"releases/download/{tag}/{ASSET}",
        text,
    )
    if count != 1:
        fail(f"{FORMULA}: expected one SafariExtension.zip URL, found {count}")
    text = replace_sha_after_url(text, ASSET, sha256, FORMULA)
    # A revision repairs the release it was added for, not the next one.
    text = re.sub(r"(?m)^[ \t]*revision \d+\n", "", text)

    write(FORMULA, text)
    report("safari-ext-dearrow", pinned, version)


if __name__ == "__main__":
    main()
