#!/usr/bin/env python3
"""Pin Formula/shurectl.rb to the latest Humblemonk/shurectl release.

Upstream's own tap builds shurectl from source; this tap installs the universal
macOS binary attached to the release, so the version comes from the release tag
and the checksum is the SHA-256 of
`shurectl-v<version>-universal-apple-darwin.tar.gz`. Upstream started shipping
per-platform archives (and `.sha256` sidecars) at v2.17.0; releases before that
attached one bare `shurectl` binary, so an older tag fails loudly here instead
of pinning an asset that does not exist.
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

REPO = "Humblemonk/shurectl"
FORMULA = "Formula/shurectl.rb"
ASSET = "shurectl-v{version}-universal-apple-darwin.tar.gz"

_TAG = re.compile(r"v\d+(?:\.\d+)+")
_PIN = r"shurectl-v([^/\"]+)-universal-apple-darwin\.tar\.gz"


def main() -> None:
    tag = latest_tag(REPO)
    if not _TAG.fullmatch(tag):
        fail(f"{REPO} release tag {tag!r} is not v<major>.<minor>...; refusing to pin it")
    version = version_from_tag(tag)

    text = read(FORMULA)
    pinned = pinned_version(text, _PIN, FORMULA)
    if pinned == version:
        report("shurectl", pinned, version)
        return

    asset = ASSET.format(version=version)
    sha256 = asset_sha256(REPO, tag, asset)

    text, count = re.subn(
        r"releases/download/v[0-9][^/\"]+/shurectl-v[^/\"]+-universal-apple-darwin\.tar\.gz",
        f"releases/download/{tag}/{asset}",
        text,
    )
    if count != 1:
        fail(f"{FORMULA}: expected one universal macOS asset URL, found {count}")
    text = replace_sha_after_url(text, asset, sha256, FORMULA)

    write(FORMULA, text)
    report("shurectl", pinned, version)


if __name__ == "__main__":
    main()
