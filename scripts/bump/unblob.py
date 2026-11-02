#!/usr/bin/env python3
"""Pin Formula/unblob.rb to the latest unblob release.

unblob and most of its dependency tree publish prebuilt extension wheels only
(unblob itself is a PyO3/maturin project; lief, pyperscan, cryptography, lz4,
... are compiled too), so the formula installs the published wheels for macOS
arm64 and CPython 3.14 instead of compiling each dependency from source.

The formula's own `url` is unblob's wheel (`using: :nounzip` keeps it intact);
the dependency wheels live in generated resource blocks. This script resolves
the whole wheel set from PyPI, pins every URL and SHA-256, and moves the
formula's url/version/checksum with the release. The generated list sits
between two marker comments; everything outside them is maintained by hand.
"""

import hashlib
import json
import os
import pathlib
import re
import subprocess
import sys
import tempfile
import urllib.request

from _common import (
    fail,
    pinned_version,
    read,
    report,
    set_version_stanza,
    write,
)

FORMULA = "Formula/unblob.rb"
PYTHON = "3.14"
PLATFORM = "macosx_11_0_arm64"
ABIS = ("cp314", "abi3", "none")

_VERSION = r'(?m)^\s*version "([^"]+)"$'
_URL = r'  url "https://files\.pythonhosted\.org/[^"]*\.whl", using: :nounzip\n'
_BEGIN = "  # BEGIN GENERATED WHEELS (scripts/bump/unblob.py)\n"
_END = "  # END GENERATED WHEELS\n"


def _pypi(path: str) -> dict:
    url = f"https://pypi.org/pypi/{path}/json"
    request = urllib.request.Request(url, headers={"User-Agent": "fmu-homebrew-bump"})
    try:
        with urllib.request.urlopen(request, timeout=120) as response:
            return json.load(response)
    except OSError as exc:
        fail(f"could not query {url}: {exc}")
    raise AssertionError("unreachable")


def _latest_version() -> str:
    forced = os.environ.get("RELEASE_TAG", "").strip()
    if forced:
        return forced.lstrip("v")
    return _pypi("unblob")["info"]["version"]


def _wheels(version: str) -> list[tuple[str, str, str]]:
    """Resolve (name, url, sha256) for the macOS arm64 / CPython wheels."""
    with tempfile.TemporaryDirectory(prefix="unblob-wheels-") as tmp:
        command = [
            sys.executable,
            "-m",
            "pip",
            "download",
            f"unblob=={version}",
            "--only-binary=:all:",
            "--python-version",
            PYTHON,
            "--implementation",
            "cp",
            "--platform",
            PLATFORM,
            "--quiet",
            "--dest",
            tmp,
        ]
        for abi in ABIS:
            command += ["--abi", abi]
        try:
            subprocess.run(command, check=True, capture_output=True, text=True)
        except subprocess.CalledProcessError as exc:
            fail(f"could not resolve unblob {version} wheels: {exc.stderr.strip()}")

        wheels = []
        for wheel in sorted(pathlib.Path(tmp).glob("*.whl")):
            name, wheel_version = wheel.name.split("-")[:2]
            digest = hashlib.sha256(wheel.read_bytes()).hexdigest()
            release = _pypi(f"{name.replace('_', '-')}/{wheel_version}")
            entry = next(
                (file for file in release["urls"] if file["filename"] == wheel.name), None
            )
            if entry is None:
                fail(f"{wheel.name}: not listed on PyPI for {name} {wheel_version}")
            if digest != entry["digests"]["sha256"]:
                fail(f"{wheel.name}: downloaded bytes do not match the PyPI digest")
            wheels.append((name.replace("_", "-"), entry["url"], digest))
        return wheels


def _render_resources(wheels: list[tuple[str, str, str]]) -> str:
    lines = [_BEGIN]
    for name, url, sha256 in sorted(wheels):
        lines += [
            f'  resource "{name}" do\n',
            f'    url "{url}"\n',
            f'    sha256 "{sha256}"\n',
            "  end\n",
            "\n",
        ]
    lines.append(_END)
    return "".join(lines)


def main() -> None:
    version = _latest_version()
    text = read(FORMULA)
    pinned = pinned_version(text, _VERSION, FORMULA)
    if pinned == version:
        report("unblob", pinned, version)
        return

    wheels = _wheels(version)
    own = next((wheel for wheel in wheels if wheel[0] == "unblob"), None)
    if own is None:
        fail(f"unblob {version}: the wheel set does not include unblob itself")
    _, own_url, own_sha = own
    dependencies = [wheel for wheel in wheels if wheel[0] != "unblob"]

    text, count = re.subn(_URL, f'  url "{own_url}", using: :nounzip\n', text)
    if count != 1:
        fail(f"{FORMULA}: expected one nounzip wheel URL, found {count}")
    text = set_version_stanza(text, version, FORMULA)
    # The checksum follows the version stanza; `replace_sha_after_url` cannot be
    # used here because the version line sits between the url and the sha256.
    text, count = re.subn(
        r'(?m)(^  version "[^"]+"\n  sha256 ")([0-9a-f]{64})(")',
        lambda match: match.group(1) + own_sha + match.group(3),
        text,
    )
    if count != 1:
        fail(f"{FORMULA}: expected one sha256 after the version stanza, found {count}")

    start = text.find(_BEGIN)
    end = text.find(_END)
    if start == -1 or end == -1 or end < start:
        fail(f"{FORMULA}: generated-wheel markers not found")
    text = text[:start] + _render_resources(dependencies) + text[end + len(_END) :]

    write(FORMULA, text)
    report("unblob", pinned, version)


if __name__ == "__main__":
    main()
