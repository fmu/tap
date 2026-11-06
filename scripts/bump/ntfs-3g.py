#!/usr/bin/env python3
"""Pin the ntfs-3g userspace formulae to the latest tuxera/ntfs-3g release.

ntfs-3g publishes plain version tags and no release assets, so the formulae
build the tagged source; the version comes from the tag and each checksum is the
SHA-256 of that tag's source archive. The library and the tools come from the
same release, so they are bumped together:

  Formula/libntfs-3g.rb   the library partclone links
  Formula/ntfsprogs.rb    mkntfs, ntfsls, ntfscat, ntfsclone, ...
"""

import re

from _common import (
    download_sha256,
    drop_bottle_block,
    fail,
    latest_tag,
    pinned_version,
    read,
    replace_sha_after_url,
    report,
    version_from_tag,
    write,
)

REPO = "tuxera/ntfs-3g"
FORMULAS = ("Formula/libntfs-3g.rb", "Formula/ntfsprogs.rb")

_TAG = re.compile(r"\d+(?:\.\d+)+")
_PIN = r"ntfs-3g/archive/refs/tags/([^/\"]+)\.tar\.gz"
_URL = re.compile(r"https://github\.com/tuxera/ntfs-3g/archive/refs/tags/[^\"]+\.tar\.gz")


def formula_name(formula: str) -> str:
    return formula.removeprefix("Formula/").removesuffix(".rb")


def main() -> None:
    tag = latest_tag(REPO)
    if not _TAG.fullmatch(tag):
        fail(f"{REPO}: release tag {tag!r} is not a version; refusing to pin it")
    version = version_from_tag(tag)

    texts = {formula: read(formula) for formula in FORMULAS}
    pins = {formula: pinned_version(texts[formula], _PIN, formula) for formula in FORMULAS}
    if len(set(pins.values())) != 1:
        pins_text = ", ".join(f"{formula}={pins[formula]}" for formula in FORMULAS)
        fail(f"{REPO}: formulae disagree on the pinned version ({pins_text})")
    pinned = pins[FORMULAS[0]]

    if pinned == version:
        for formula in FORMULAS:
            report(formula_name(formula), pinned, version)
        return

    url = f"https://github.com/{REPO}/archive/refs/tags/{tag}.tar.gz"
    sha256 = download_sha256(url)

    for formula in FORMULAS:
        text, count = _URL.subn(url, texts[formula])
        if count != 1:
            fail(f"{formula}: expected one tagged source archive URL, found {count}")
        text = replace_sha_after_url(text, f"{tag}.tar.gz", sha256, formula)
        text = drop_bottle_block(text, formula)
        write(formula, text)
        report(formula_name(formula), pinned, version)


if __name__ == "__main__":
    main()
