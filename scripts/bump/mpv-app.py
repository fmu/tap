#!/usr/bin/env python3
"""Pin Casks/mpv-app.rb to the latest mpv-player/mpv stable release.

mpv publishes one macOS asset per build macOS version and architecture, and the
cask selects one per host; every one of the four has to be re-pinned together,
because a release only ships the set it built that run.
"""

from _common import (
    asset_sha256,
    fail,
    latest_tag,
    pinned_version,
    read,
    report,
    replace_sha_before_url,
    set_version_stanza,
    version_from_tag,
    write,
)

REPO = "mpv-player/mpv"
CASK = "Casks/mpv-app.rb"
ASSETS = (
    "macos-14-arm.zip",
    "macos-15-arm.zip",
    "macos-26-arm.zip",
    "macos-15-intel.zip",
)


def main() -> None:
    tag = latest_tag(REPO)
    version = version_from_tag(tag)
    text = read(CASK)
    pinned = pinned_version(text, r'(?m)^\s*version "([^"]+)"$', CASK)

    if pinned == version:
        report("mpv-app", pinned, version)
        return

    if not tag.startswith("v"):
        fail(f"{REPO}: expected a v-prefixed stable tag, got {tag!r}")

    for asset in ASSETS:
        sha256 = asset_sha256(REPO, tag, f"mpv-v{version}-{asset}")
        text = replace_sha_before_url(text, asset, sha256, CASK)

    text = set_version_stanza(text, version, CASK)

    write(CASK, text)
    report("mpv-app", pinned, version)


if __name__ == "__main__":
    main()
