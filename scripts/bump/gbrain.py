#!/usr/bin/env python3
"""Pin Formula/gbrain.rb to the latest garrytan/gbrain release.

Upstream publishes one Bun-compiled binary per supported platform; both are
hashed so `brew install gbrain` installs exactly the bytes the release names.
"""

import re

from _common import (
    asset_sha256,
    fail,
    latest_tag,
    pinned_version,
    read,
    report,
    version_from_tag,
    write,
)

REPO = "garrytan/gbrain"
FORMULA = "Formula/gbrain.rb"
ASSETS = ("gbrain-darwin-arm64", "gbrain-linux-x64")


def main() -> None:
    tag = latest_tag(REPO)
    version = version_from_tag(tag)
    text = read(FORMULA)
    pinned = pinned_version(text, r"releases/download/v([^/]+)/", FORMULA)

    if pinned == version:
        report("gbrain", pinned, version)
        return

    for asset in ASSETS:
        sha256 = asset_sha256(REPO, tag, asset)
        pattern = re.compile(r'(%s"\n\s*sha256 ")([0-9a-f]{64})(")' % re.escape(asset))
        text, count = pattern.subn(
            lambda match, sha=sha256: match.group(1) + sha + match.group(3), text
        )
        if count != 1:
            fail(f"{FORMULA}: expected one sha256 after the {asset} URL, found {count}")

    text, count = re.subn(
        r"releases/download/v[0-9][^/]*/", f"releases/download/v{version}/", text
    )
    if count != 2:
        fail(f"{FORMULA}: expected two versioned release URLs, found {count}")

    write(FORMULA, text)
    report("gbrain", pinned, version)


if __name__ == "__main__":
    main()
