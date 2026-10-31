#!/usr/bin/env python3
"""Pin Formula/designcraft-cli.rb to the latest storytold/designcraft release.

The app is the `designcraft` cask in homebrew-cask and the CLI is built from the
same tag, so the formula follows one upstream release: the version comes from
the release tag, and the checksum is the SHA-256 of that tag's source archive,
which is what Homebrew builds. Homebrew recovers the formula version from the
archive URL, so anything but a v<major>.<minor>... tag is refused rather than
pinned under a version Homebrew would have to guess.
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

REPO = "storytold/designcraft"
FORMULA = "Formula/designcraft-cli.rb"

_TAG = re.compile(r"v\d+(?:\.\d+)+")
_ARCHIVE = r"archive/refs/tags/v([^/]+)\.tar\.gz"


def main() -> None:
    tag = latest_tag(REPO)
    if not _TAG.fullmatch(tag):
        fail(f"{REPO} release tag {tag!r} is not v<major>.<minor>...; refusing to pin it")
    version = version_from_tag(tag)

    text = read(FORMULA)
    pinned = pinned_version(text, _ARCHIVE, FORMULA)
    if pinned == version:
        report("designcraft-cli", pinned, version)
        return

    archive = f"https://github.com/{REPO}/archive/refs/tags/{tag}.tar.gz"
    sha256 = download_sha256(archive)

    text, count = re.subn(
        r"archive/refs/tags/v[0-9][^/]*\.tar\.gz",
        f"archive/refs/tags/{tag}.tar.gz",
        text,
    )
    if count != 1:
        fail(f"{FORMULA}: expected one tag archive URL, found {count}")
    text = replace_sha_after_url(text, f"archive/refs/tags/{tag}.tar.gz", sha256, FORMULA)

    write(FORMULA, text)
    report("designcraft-cli", pinned, version)


if __name__ == "__main__":
    main()
