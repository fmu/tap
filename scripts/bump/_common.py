"""Shared helpers for the scheduled upstream bump scripts.

Each script re-pins one package to upstream's latest release: the version comes
from the release tag, and every checksum is the SHA-256 of the release asset as
downloaded from GitHub, so a missing or replaced asset fails the bump instead of
pinning bytes nobody can fetch again.

Environment:
  RELEASE_TAG  pin this tag instead of asking for the latest release (used by
               the workflow's manual input; empty means look it up).
  GH_TOKEN     GitHub token for the release API; the workflow supplies one, and
               it only raises the unauthenticated rate limit locally.
"""

from __future__ import annotations

import hashlib
import json
import os
import pathlib
import re
import sys
import time
import urllib.error
import urllib.request

ROOT = pathlib.Path(__file__).resolve().parents[2]
USER_AGENT = "fmu-homebrew-bump"

_VERSION_STANZA = re.compile(r'(?m)^(\s*)version "[^"]+"$')


def fail(message: str) -> None:
    print(f"error: {message}", file=sys.stderr)
    sys.exit(1)


def read(relpath: str) -> str:
    return (ROOT / relpath).read_text(encoding="utf-8")


def write(relpath: str, text: str) -> None:
    path = ROOT / relpath
    if path.read_text(encoding="utf-8") != text:
        path.write_text(text, encoding="utf-8")


def _json(url: str) -> dict:
    headers = {"Accept": "application/vnd.github+json", "User-Agent": USER_AGENT}
    token = os.environ.get("GH_TOKEN") or os.environ.get("GITHUB_TOKEN")
    if token:
        headers["Authorization"] = f"Bearer {token}"
    request = urllib.request.Request(url, headers=headers)
    try:
        with urllib.request.urlopen(request, timeout=60) as response:
            return json.load(response)
    except urllib.error.URLError as exc:
        fail(f"could not query {url}: {exc}")


def latest_tag(repo: str) -> str:
    """Return the tag to pin: RELEASE_TAG when given, else upstream's latest."""
    forced = os.environ.get("RELEASE_TAG", "").strip()
    if forced:
        return forced
    release = _json(f"https://api.github.com/repos/{repo}/releases/latest")
    tag = release.get("tag_name")
    if not tag:
        fail(f"{repo} has no published latest release")
    return tag


def version_from_tag(tag: str) -> str:
    """Casks and formulae spell the version without the release tag's `v`."""
    return tag[1:] if tag.startswith("v") else tag


def download_sha256(url: str) -> str:
    """Hash any asset URL by streaming it, so large files stay out of memory."""
    for attempt in range(1, 4):
        digest = hashlib.sha256()
        try:
            request = urllib.request.Request(url, headers={"User-Agent": USER_AGENT})
            with urllib.request.urlopen(request, timeout=300) as response:
                while chunk := response.read(1 << 20):
                    digest.update(chunk)
            return digest.hexdigest()
        except (urllib.error.URLError, TimeoutError) as exc:
            if attempt == 3:
                fail(f"could not download {url}: {exc}")
            time.sleep(5 * attempt)
    raise AssertionError("unreachable")


def asset_sha256(repo: str, tag: str, asset: str) -> str:
    """Hash a GitHub release asset by streaming it."""
    return download_sha256(f"https://github.com/{repo}/releases/download/{tag}/{asset}")


def raw_file(repo: str, tag: str, path: str) -> str:
    """Read one file from a repository tag.

    Used to read the exact engine pins a published release verifies, so the
    tap follows the released tag rather than whatever upstream's main branch
    says today.
    """
    url = f"https://raw.githubusercontent.com/{repo}/{tag}/{path}"
    request = urllib.request.Request(url, headers={"User-Agent": USER_AGENT})
    try:
        with urllib.request.urlopen(request, timeout=60) as response:
            return response.read().decode("utf-8")
    except urllib.error.URLError as exc:
        fail(f"could not read {url}: {exc}")
    raise AssertionError("unreachable")


def pinned_version(text: str, pattern: str, where: str) -> str:
    match = re.search(pattern, text)
    if not match:
        fail(f"{where}: could not find the pinned version")
    return match.group(1)


def set_version_stanza(text: str, version: str, where: str) -> str:
    text, count = _VERSION_STANZA.subn(
        lambda match: f'{match.group(1)}version "{version}"', text
    )
    if count != 1:
        fail(f"{where}: expected exactly one version stanza, found {count}")
    return text


def replace_sha_before_url(text: str, url_fragment: str, sha256: str, where: str) -> str:
    """Rewrite the `sha256` line that precedes a `url` line naming the asset.

    Casks put the checksum first and the URL second; matching both ties the new
    hash to the asset it belongs to instead of to whichever hash came first.
    """
    pattern = re.compile(
        r'(sha256 ")([0-9a-f]{64})("\n\s*url "[^"\n]*'
        + re.escape(url_fragment)
        + r'[^"\n]*")'
    )
    text, count = pattern.subn(lambda match: match.group(1) + sha256 + match.group(3), text)
    if count != 1:
        fail(f"{where}: expected one sha256 before the {url_fragment} URL, found {count}")
    return text


def replace_sha_after_url(text: str, url_fragment: str, sha256: str, where: str) -> str:
    """Rewrite the `sha256` line that follows a `url` line naming the asset."""
    pattern = re.compile(
        r'(url "[^"\n]*'
        + re.escape(url_fragment)
        + r'[^"\n]*"\n\s*sha256 ")([0-9a-f]{64})(")'
    )
    text, count = pattern.subn(lambda match: match.group(1) + sha256 + match.group(3), text)
    if count != 1:
        fail(f"{where}: expected one sha256 after the {url_fragment} URL, found {count}")
    return text


def report(package: str, old: str, new: str) -> None:
    if old == new:
        print(f"{package}: already at {new}")
    else:
        print(f"{package}: {old} -> {new}")
