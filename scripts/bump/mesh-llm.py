#!/usr/bin/env python3
"""Pin Formula/mesh-llm.rb to the latest upstream release."""

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

REPO = "Mesh-LLM/mesh-llm"
FORMULA = "Formula/mesh-llm.rb"
PIN = r"mesh-llm-v([^/\"]+)-aarch64-apple-darwin\.tar\.gz"


def main() -> None:
    tag = latest_tag(REPO)
    version = version_from_tag(tag)
    asset = f"mesh-llm-v{version}-aarch64-apple-darwin.tar.gz"

    text = read(FORMULA)
    pinned = pinned_version(text, PIN, FORMULA)
    if pinned == version:
        report("mesh-llm", pinned, version)
        return

    sha256 = asset_sha256(REPO, tag, asset)

    text, count = re.subn(
        r"https://github\.com/Mesh-LLM/mesh-llm/releases/download/[^\"]+/"
        r"mesh-llm-v[^\"]+-aarch64-apple-darwin\.tar\.gz",
        f"https://github.com/{REPO}/releases/download/{tag}/{asset}",
        text,
    )
    if count != 1:
        fail(f"{FORMULA}: expected one mesh-llm release URL, found {count}")
    text = replace_sha_after_url(text, asset, sha256, FORMULA)

    write(FORMULA, text)
    report("mesh-llm", pinned, version)


if __name__ == "__main__":
    main()
