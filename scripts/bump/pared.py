#!/usr/bin/env python3
"""Pin both Pared artifacts to one 4evy/pared release.

The app (Casks/pared-app.rb) and the CLI (Formula/pared.rb) are built from the
same tag, so they are re-pinned together; disagreeing pins would ship an app and
a CLI from different releases.
"""

import re

from _common import (
    asset_sha256,
    fail,
    latest_tag,
    pinned_version,
    read,
    report,
    replace_sha_after_url,
    replace_sha_before_url,
    set_version_stanza,
    version_from_tag,
    write,
)

REPO = "4evy/pared"
CASK = "Casks/pared-app.rb"
FORMULA = "Formula/pared.rb"


def main() -> None:
    tag = latest_tag(REPO)
    version = version_from_tag(tag)

    cask = read(CASK)
    formula = read(FORMULA)
    cask_pinned = pinned_version(cask, r'(?m)^\s*version "([^"]+)"$', CASK)
    formula_pinned = pinned_version(formula, r"releases/download/([^/]+)/pared-macos-arm64", FORMULA)

    if cask_pinned != formula_pinned:
        fail(
            f"{CASK} is at {cask_pinned} but {FORMULA} is at {formula_pinned}; "
            "re-pin both from one release"
        )

    if cask_pinned == version:
        report("pared-app", cask_pinned, version)
        report("pared", formula_pinned, version)
        return

    cask_sha = asset_sha256(REPO, tag, "pared-app-macos-arm64.zip")
    formula_sha = asset_sha256(REPO, tag, "pared-macos-arm64.tar.gz")

    # The cask interpolates `#{version}` in its URL, so only the version stanza
    # and the checksum move; a literal URL would be a second place to forget.
    if "releases/download/#{version}/pared-app-macos-arm64.zip" not in cask:
        fail(f"{CASK}: expected the pared-app URL to interpolate #{{version}}")
    cask = set_version_stanza(cask, version, CASK)
    cask = replace_sha_before_url(cask, "pared-app-macos-arm64.zip", cask_sha, CASK)

    formula, count = re.subn(
        r"releases/download/[^/]+/pared-macos-arm64\.tar\.gz",
        f"releases/download/{version}/pared-macos-arm64.tar.gz",
        formula,
    )
    if count != 1:
        fail(f"{FORMULA}: expected one pared CLI download URL, found {count}")
    formula = replace_sha_after_url(formula, "pared-macos-arm64.tar.gz", formula_sha, FORMULA)

    write(CASK, cask)
    write(FORMULA, formula)
    report("pared-app", cask_pinned, version)
    report("pared", formula_pinned, version)


if __name__ == "__main__":
    main()
