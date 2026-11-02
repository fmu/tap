#!/usr/bin/env python3
"""Pin Formula/designcraft-cli.rb to the latest storytold/designcraft release.

The app is the `designcraft` cask in homebrew-cask and the CLI ships as a
self-contained universal macOS binary built from the same tag, so the formula
follows one upstream release: the version comes from the release tag, and the
checksum is the SHA-256 of that tag's
`designcraft-cli-<version>-macos-universal.zip` asset, which is what Homebrew
installs. Homebrew recovers the formula version from the asset URL, so anything
but a v<major>.<minor>... tag is refused rather than pinned under a version
Homebrew would have to guess.
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
ASSET = "designcraft-cli-{version}-macos-universal.zip"

_TAG = re.compile(r"v\d+(?:\.\d+)+")
_PIN = r"designcraft-cli-([^/\"]+)-macos-universal\.zip"


def main() -> None:
    tag = latest_tag(REPO)
    if not _TAG.fullmatch(tag):
        fail(f"{REPO} release tag {tag!r} is not v<major>.<minor>...; refusing to pin it")
    version = version_from_tag(tag)

    text = read(FORMULA)
    pinned = pinned_version(text, _PIN, FORMULA)
    if pinned == version:
        report("designcraft-cli", pinned, version)
        return

    asset = ASSET.format(version=version)
    url = f"https://github.com/{REPO}/releases/download/{tag}/{asset}"
    sha256 = download_sha256(url)

    text, count = re.subn(
        r"releases/download/v[0-9][^/\"]+/designcraft-cli-[^/\"]+-macos-universal\.zip",
        f"releases/download/{tag}/{asset}",
        text,
    )
    if count != 1:
        fail(f"{FORMULA}: expected one CLI asset URL, found {count}")
    text = replace_sha_after_url(text, asset, sha256, FORMULA)

    write(FORMULA, text)
    report("designcraft-cli", pinned, version)


if __name__ == "__main__":
    main()
