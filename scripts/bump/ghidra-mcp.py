#!/usr/bin/env python3
"""Pin Formula/ghidra-mcp.rb to the latest LaurieWired/GhidraMCP release.

The release zip carries two artifacts that have to move together: the Ghidra
extension, which is compiled against one exact Ghidra release, and the Python
MCP server's sdist. Before re-pinning, this script therefore checks that

  * the extension targets the Ghidra version pinned by Formula/ghidra@12.1.rb,
    because a mismatched extension only fails later, inside the affected tool;
  * the sdist's runtime dependencies still match the formula's pinned Python
    resources, because the resources are installed with `pip --no-deps` and a
    changed requirement would silently produce an unimportable install.

Anything unexpected aborts before the formula is written.
"""

from __future__ import annotations

import hashlib
import io
import re
import tarfile
import time
import urllib.error
import urllib.request
import zipfile

from _common import (
    USER_AGENT,
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

REPO = "LaurieWired/GhidraMCP"
FORMULA = "Formula/ghidra-mcp.rb"
GHIDRA_FORMULA = "Formula/ghidra@12.1.rb"

# ghidra-mcp 2.0.0's [project.dependencies]; the resources below are the
# python@3.15 closure of exactly these two requirements. A new release that
# changes them needs its resources re-resolved, not a silent bump.
EXPECTED_REQUIRES = {"mcp": "<2,>=1.30", "requests": "<3,>=2.32"}

# Provided by Homebrew formulae the formula depends on, not by a resource.
CORE_PACKAGES = {"certifi", "cryptography", "pydantic", "rpds-py"}

EXTENSION_PATTERN = re.compile(r"(?:^|/)ghidra_(?P<version>[^/]+)_PUBLIC_[^/]*_GhidraMCP\.zip$")
SDIST_PATTERN = re.compile(r"(?:^|/)ghidra_mcp-[^/]+\.tar\.gz$")
RESOURCE_PATTERN = re.compile(r'(?m)^  resource "(?P<name>[^"]+)" do$')


def release_asset(version: str) -> str:
    """The release asset name: 2.0 -> GhidraMCP-release-2-0.zip."""
    return f"GhidraMCP-release-{version.replace('.', '-')}.zip"


def release_url(tag: str, asset: str) -> str:
    return f"https://github.com/{REPO}/releases/download/{tag}/{asset}"


def _download(url: str) -> bytes:
    for attempt in range(1, 4):
        try:
            request = urllib.request.Request(url, headers={"User-Agent": USER_AGENT})
            with urllib.request.urlopen(request, timeout=300) as response:
                return response.read()
        except (urllib.error.URLError, TimeoutError) as exc:
            if attempt == 3:
                fail(f"could not download {url}: {exc}")
            time.sleep(5 * attempt)
    raise AssertionError("unreachable")


def _extension_version(release: zipfile.ZipFile) -> str:
    """Read the Ghidra version the extension inside the release was built for."""
    matches = [name for name in release.namelist() if EXTENSION_PATTERN.search(name)]
    if len(matches) != 1:
        fail(f"expected one Ghidra extension zip in the release, found {len(matches)}")

    asset = EXTENSION_PATTERN.search(matches[0])
    assert asset is not None
    name_version = asset.group("version")
    with zipfile.ZipFile(io.BytesIO(release.read(matches[0]))) as extension:
        properties = [name for name in extension.namelist() if name.endswith("extension.properties")]
        if len(properties) != 1:
            fail(f"expected one extension.properties in {matches[0]}, found {len(properties)}")
        text = extension.read(properties[0]).decode("utf-8")

    match = re.search(r"(?m)^version=(.+)$", text)
    if match is None:
        fail(f"{matches[0]}: extension.properties has no version")
    version = match.group(1).strip()
    if version != name_version:
        fail(
            f"{matches[0]}: the asset name says Ghidra {name_version} but "
            f"extension.properties says Ghidra {version}"
        )
    return version


def _base_requirements(metadata: str) -> dict[str, str]:
    """Normalize the sdist's unconditional Requires-Dist lines."""
    requirements: dict[str, str] = {}
    for line in metadata.splitlines():
        if not line.startswith("Requires-Dist:"):
            continue
        requirement = line.split(":", 1)[1].strip()
        if "extra ==" in requirement:
            continue
        match = re.match(r"([A-Za-z0-9][A-Za-z0-9._-]*)\s*(.*)", requirement)
        if match is None:
            fail(f"could not parse Requires-Dist line: {line}")
        name = re.sub(r"[-_.]+", "-", match.group(1)).lower()
        specifier = ",".join(sorted(part.strip() for part in match.group(2).split(",") if part.strip()))
        requirements[name] = specifier
    return requirements


def _sdist_requirements(release: zipfile.ZipFile) -> dict[str, str]:
    """Read the runtime dependencies declared by the release's Python sdist."""
    matches = [name for name in release.namelist() if SDIST_PATTERN.search(name)]
    if len(matches) != 1:
        fail(f"expected one ghidra-mcp sdist in the release, found {len(matches)}")

    with tarfile.open(fileobj=io.BytesIO(release.read(matches[0])), mode="r:gz") as sdist:
        metadata_members = [
            member for member in sdist.getmembers() if member.isfile() and member.name.endswith("/PKG-INFO")
        ]
        if len(metadata_members) != 1:
            fail(f"{matches[0]}: expected one PKG-INFO, found {len(metadata_members)}")
        extracted = sdist.extractfile(metadata_members[0])
        if extracted is None:
            fail(f"{matches[0]}: could not read {metadata_members[0].name}")
        metadata = extracted.read().decode("utf-8")

    return _base_requirements(metadata)


def _format_requirements(requirements: dict[str, str]) -> str:
    return ", ".join(f"{name}{specifier}" for name, specifier in sorted(requirements.items()))


def _set_release_url(text: str, tag: str, version: str, where: str) -> str:
    """Rewrite the release download URL.

    Homebrew derives the formula version from the asset name
    (`GhidraMCP-release-2-0.zip` is version 2.0), so there is no `version`
    stanza to update: the URL is the pin.
    """
    asset = release_asset(version)
    pattern = re.compile(
        r'(?m)^(\s*url "https://github\.com/'
        + re.escape(REPO)
        + r'/releases/download/)[^/"]+/GhidraMCP-release-[^/"]+\.zip(")$'
    )
    text, count = pattern.subn(
        lambda match: f"{match.group(1)}{tag}/{asset}{match.group(2)}", text
    )
    if count != 1:
        fail(f"{where}: expected one GhidraMCP release download URL, found {count}")
    return text


def main() -> None:
    tag = latest_tag(REPO)
    version = version_from_tag(tag)
    text = read(FORMULA)
    pinned_dashed = pinned_version(text, r"GhidraMCP-release-([0-9]+(?:-[0-9]+)*)\.zip", FORMULA)
    pinned = pinned_dashed.replace("-", ".")

    if pinned == version:
        report("ghidra-mcp", pinned, version)
        return

    asset = release_asset(version)
    sha256 = asset_sha256(REPO, tag, asset)
    release_bytes = _download(release_url(tag, asset))
    if hashlib.sha256(release_bytes).hexdigest() != sha256:
        fail(f"{asset}: the download changed between hashing and inspection; re-run the bump")

    release = zipfile.ZipFile(io.BytesIO(release_bytes))

    # The extension and the Ghidra keg are a pair; never pin them apart.
    ghidra = pinned_version(read(GHIDRA_FORMULA), r'(?m)^\s*version "([^"]+)"$', GHIDRA_FORMULA)
    extension_version = _extension_version(release)
    if extension_version != ghidra:
        fail(
            f"{asset}: the GhidraMCP extension targets Ghidra {extension_version}, but "
            f"{GHIDRA_FORMULA} pins {ghidra}; bump the Ghidra keg and the extension together"
        )

    # The resources are installed with `pip --no-deps`, so the closure has to be
    # re-resolved by hand whenever ghidra-mcp's declared dependencies move.
    requirements = _sdist_requirements(release)
    if requirements != EXPECTED_REQUIRES:
        fail(
            f"{asset}: ghidra-mcp's runtime dependencies changed "
            f"(expected {_format_requirements(EXPECTED_REQUIRES)}, "
            f"found {_format_requirements(requirements)}). Re-resolve {FORMULA}'s Python "
            "resources for python@3.15, update the resource stanzas and EXPECTED_REQUIRES, "
            "then run the bump again; nothing was written"
        )

    resources = set(RESOURCE_PATTERN.findall(text))
    missing = sorted(name for name in requirements if name not in resources and name not in CORE_PACKAGES)
    if missing:
        fail(
            f"{FORMULA} has no resource for {', '.join(missing)}, which ghidra-mcp requires; "
            "re-resolve the Python resources before bumping"
        )

    text = _set_release_url(text, tag, version, FORMULA)
    text = replace_sha_after_url(text, "GhidraMCP-release-", sha256, FORMULA)
    write(FORMULA, text)
    report("ghidra-mcp", pinned, version)


if __name__ == "__main__":
    main()
