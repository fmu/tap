#!/usr/bin/env python3
"""Pin Casks/baocut.rb to the latest JimLiu/baocut release.

The release tag carries the build number (`baocut-v3.14.0-build.85`) and the DMG
asset name repeats it, so the cask interpolates `#{version}` in its URL: only the
version stanza and the checksum move. Homebrew compares the `-build.<n>` suffix
numerically, so a rebuild of the same marketing version still upgrades.
"""

import re

from _common import (
    download_sha256,
    fail,
    latest_tag,
    pinned_version,
    read,
    report,
    replace_sha_before_url,
    set_version_stanza,
    write,
)

REPO = "JimLiu/baocut"
CASK = "Casks/baocut.rb"
ASSET = "BaoCut-{version}-aarch64-apple-darwin.dmg"
# As spelled in the cask URL, which interpolates the version.
URL_ASSET = "BaoCut-#{version}-aarch64-apple-darwin.dmg"

_TAG = re.compile(r"baocut-v(\d+(?:\.\d+)+-build\.\d+)")


def main() -> None:
    tag = latest_tag(REPO)
    match = _TAG.fullmatch(tag)
    if not match:
        fail(f"{REPO} release tag {tag!r} is not baocut-v<version>-build.<n>; refusing to pin it")
    version = match.group(1)

    text = read(CASK)
    pinned = pinned_version(text, r'(?m)^\s*version "([^"]+)"$', CASK)
    if pinned == version:
        report("baocut", pinned, version)
        return

    if URL_ASSET not in text:
        fail(f"{CASK}: expected the DMG URL to interpolate #{{version}}")

    asset = ASSET.format(version=version)
    url = f"https://github.com/{REPO}/releases/download/{tag}/{asset}"
    sha256 = download_sha256(url)

    text = set_version_stanza(text, version, CASK)
    text = replace_sha_before_url(text, URL_ASSET, sha256, CASK)

    write(CASK, text)
    report("baocut", pinned, version)


if __name__ == "__main__":
    main()
