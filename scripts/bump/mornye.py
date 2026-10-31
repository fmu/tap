#!/usr/bin/env python3
"""Pin Casks/mornye.rb to the latest mornyeapp/Mornye-Desktop release.

The release also carries a `SHA256SUMS.txt`; the hash below is computed from the
DMG itself, which is the artifact Homebrew downloads.
"""

from _common import (
    asset_sha256,
    latest_tag,
    pinned_version,
    read,
    report,
    replace_sha_before_url,
    set_version_stanza,
    version_from_tag,
    write,
)

REPO = "mornyeapp/Mornye-Desktop"
CASK = "Casks/mornye.rb"


def main() -> None:
    tag = latest_tag(REPO)
    version = version_from_tag(tag)
    text = read(CASK)
    pinned = pinned_version(text, r'(?m)^\s*version "([^"]+)"$', CASK)

    if pinned == version:
        report("mornye", pinned, version)
        return

    asset = f"Mornye-v{version}-macos-universal.dmg"
    sha256 = asset_sha256(REPO, tag, asset)
    text = set_version_stanza(text, version, CASK)
    text = replace_sha_before_url(text, "-macos-universal.dmg", sha256, CASK)

    write(CASK, text)
    report("mornye", pinned, version)


if __name__ == "__main__":
    main()
