#!/usr/bin/env python3
"""Pin Casks/iqualize.rb to the latest dariuscorvus/iqualize release."""

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

REPO = "dariuscorvus/iqualize"
CASK = "Casks/iqualize.rb"


def main() -> None:
    tag = latest_tag(REPO)
    version = version_from_tag(tag)
    text = read(CASK)
    pinned = pinned_version(text, r'(?m)^\s*version "([^"]+)"$', CASK)

    if pinned == version:
        report("iqualize", pinned, version)
        return

    sha256 = asset_sha256(REPO, tag, f"iQualize-{version}.dmg")
    text = set_version_stanza(text, version, CASK)
    text = replace_sha_before_url(text, "iQualize-", sha256, CASK)

    write(CASK, text)
    report("iqualize", pinned, version)


if __name__ == "__main__":
    main()
