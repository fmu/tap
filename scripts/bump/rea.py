#!/usr/bin/env python3
"""Pin Formula/rea.rb and the engine formulae REA verifies to one REA release.

REA is the authority for its whole version set. Each release verifies exactly
one JADX headless MCP, one Kuna and one Ghidra build, and reports every other
build as unverified, so these packages are bumped together instead of tracking
their own upstream latest:

  Formula/rea.rb                     rea-agents npm tarball
  Formula/rea-full.rb                the same tarball, for the integration launcher
  Formula/jadx-headless-mcp@<v>.rb   src/android/JadxRelease.ts  JADX_RELEASE.version
  Formula/kuna@<v>.rb                src/kuna/KunaRelease.ts     KUNA_VERIFIED_VERSION
  Formula/ghidra@12.1.rb             src/ghidra/GhidraReleasePolicy.ts
                                     SUPPORTED_GHIDRA_VERSION

The pins are read from the released tag's source, not from upstream's main
branch, so an unpublished commit that already moved Kuna to a newer release
cannot make the tap advertise a combination REA never shipped. The JADX and
Kuna kegs are versioned and keg-only (`jadx-headless-mcp@<release>`,
`kuna@<release>`), so when REA starts verifying a different release this script
renames the formula and updates every reference to it instead of mutating a
name that no longer describes the pin. The unversioned formulae with those
names track upstream's latest releases and are bumped by their own scripts.

The Ghidra pin is checked but never rewritten. Moving it means a new Ghidra keg
and a GhidraMCP extension built for that exact release (see
`scripts/bump/ghidra-mcp.py`), which is a human decision; the bump fails loudly
instead of publishing a tap whose parts disagree.

Versions live in the URLs, not in `version` stanzas: Homebrew scans them from
the asset names and `brew audit --strict` rejects a redundant stanza.

Output contract matches the other scripts in this directory: stdout is the bump
commit's body. The `matches REA` verification lines belong to that body only when
this run moved the rea pin itself; a bump that leaves rea alone reports them on
stderr for the job log instead, so a gbrain-only run does not commit a pin matrix
that nothing in the run touched.

Usage:
  python3 scripts/bump/rea.py            # pin the latest REA release
  python3 scripts/bump/rea.py --check    # verify the current pins, write nothing

`--check` is what CI runs: it never touches the npm registry and exits non-zero
when the formulae no longer agree with the REA release they name. The bump
honours RELEASE_TAG like the other scripts in this directory.
"""

from __future__ import annotations

import pathlib
import re
import sys

from _common import (
    asset_sha256,
    download_sha256,
    fail,
    latest_tag,
    pinned_version,
    raw_file,
    read,
    report,
    replace_sha_after_url,
    write,
)

REPO = "morluto/rea"
TAG_PREFIX = "rea-agents-"
NPM_TARBALL = "https://registry.npmjs.org/rea-agents/-/rea-agents-{version}.tgz"

REA_FORMULA = "Formula/rea.rb"
REA_FULL_FORMULA = "Formula/rea-full.rb"
JADX_FORMULA_PREFIX = "Formula/jadx-headless-mcp@"
JADX_KEG_GLOB = "Formula/jadx-headless-mcp@*.rb"
KUNA_FORMULA_PREFIX = "Formula/kuna@"
KUNA_KEG_GLOB = "Formula/kuna@*.rb"
CI_WORKFLOW = ".github/workflows/ci.yml"
GHIDRA_FORMULA = "Formula/ghidra@12.1.rb"

JADX_REPO = "1013503897/jadx-headless-mcp"
JADX_SOURCE = "src/android/JadxRelease.ts"
KUNA_REPO = "Noelo-Lab/kuna"
KUNA_SOURCE = "src/kuna/KunaRelease.ts"
GHIDRA_SOURCE = "src/ghidra/GhidraReleasePolicy.ts"

KUNA_PLATFORMS = ("macos-arm64", "macos-x86_64", "linux-x86_64", "linux-arm64")


def _version_from_tag(tag: str) -> str:
    """REA tags name the npm package: `rea-agents-6.8.0`."""
    match = re.fullmatch(re.escape(TAG_PREFIX) + r"(\d+(?:\.\d+)+(?:[-+][0-9A-Za-z.-]+)?)", tag)
    if not match:
        fail(f"{REPO}: unexpected release tag {tag!r}; expected {TAG_PREFIX}<version>")
    return match.group(1)


def _tag_for_version(version: str) -> str:
    return f"{TAG_PREFIX}{version}"


def _engine_pins(tag: str) -> dict[str, str]:
    """Read the three engine releases a REA tag verifies."""
    jadx_source = raw_file(REPO, tag, JADX_SOURCE)
    kuna_source = raw_file(REPO, tag, KUNA_SOURCE)
    ghidra_source = raw_file(REPO, tag, GHIDRA_SOURCE)

    match = re.search(r"JADX_RELEASE\s*=\s*Object\.freeze\(\{\s*version:\s*\"([^\"]+)\"", jadx_source)
    if not match:
        fail(f"{JADX_SOURCE} at {tag}: could not find JADX_RELEASE.version")
    jadx = match.group(1)

    match = re.search(r'KUNA_VERIFIED_VERSION\s*=\s*"([^"]+)"', kuna_source)
    if not match:
        fail(f"{KUNA_SOURCE} at {tag}: could not find KUNA_VERIFIED_VERSION")
    kuna = match.group(1)

    match = re.search(r'SUPPORTED_GHIDRA_VERSION\s*=\s*"([^"]+)"', ghidra_source)
    if not match:
        fail(f"{GHIDRA_SOURCE} at {tag}: could not find SUPPORTED_GHIDRA_VERSION")
    ghidra = match.group(1)

    return {"jadx-headless-mcp": jadx, "kuna": kuna, "ghidra": ghidra}


def _rea_pin() -> str:
    return pinned_version(
        read(REA_FORMULA),
        r'registry\.npmjs\.org/rea-agents/-/rea-agents-([^"]+)\.tgz',
        REA_FORMULA,
    )


def _rea_full_pin() -> str:
    return pinned_version(
        read(REA_FULL_FORMULA),
        r'registry\.npmjs\.org/rea-agents/-/rea-agents-([^"]+)\.tgz',
        REA_FULL_FORMULA,
    )


def _versioned_formula(pattern: str) -> str:
    """The versioned keg the pattern names; there is exactly one."""
    paths = sorted(pathlib.Path(".").glob(pattern))
    if len(paths) != 1:
        fail(f"expected exactly one {pattern}, found {[str(path) for path in paths]}")
    return str(paths[0])


def _jadx_pin() -> str:
    formula = _versioned_formula(JADX_KEG_GLOB)
    return pinned_version(read(formula), r'jadx-headless-mcp-([^/"]+)-all\.jar', formula)


def _kuna_pin() -> str:
    formula = _versioned_formula(KUNA_KEG_GLOB)
    return pinned_version(read(formula), r'kuna-v([^/"]+)-macos-arm64\.tar\.gz', formula)


def _ghidra_pin() -> str:
    return pinned_version(read(GHIDRA_FORMULA), r'(?m)^\s*version "([^"]+)"$', GHIDRA_FORMULA)


def _pin_rea_tarball(formula: str, version: str, sha256: str) -> None:
    text = read(formula)
    text, count = re.subn(
        r"https://registry\.npmjs\.org/rea-agents/-/rea-agents-[^\"]+\.tgz",
        NPM_TARBALL.format(version=version),
        text,
    )
    if count != 1:
        fail(f"{formula}: expected one npm tarball URL, found {count}")
    text = replace_sha_after_url(text, f"rea-agents-{version}.tgz", sha256, formula)
    write(formula, text)


def pin_rea(version: str) -> None:
    """Pin Formula/rea.rb and the rea-full variant to one release."""
    sha256 = download_sha256(NPM_TARBALL.format(version=version))
    _pin_rea_tarball(REA_FORMULA, version, sha256)
    _pin_rea_tarball(REA_FULL_FORMULA, version, sha256)


def _formula_class_suffix(version: str) -> str:
    """Homebrew class for `name@<version>`: drop punctuation, e.g. 0.7.1 -> 071."""
    return re.sub(r"[^A-Za-z0-9]", "", version)


def _renamed_versioned_formula(
    formula: str,
    prefix: str,
    class_prefix: str,
    old: str,
    new: str,
) -> tuple[pathlib.Path, str]:
    """Return the new keg path and content, without writing anything."""
    new_path = pathlib.Path(f"{prefix}{new}.rb")
    if new_path.exists():
        fail(f"{new_path} already exists; cannot rename {formula} to {new}")

    text = read(formula)
    old_class = f"class {class_prefix}{_formula_class_suffix(old)} "
    new_class = f"class {class_prefix}{_formula_class_suffix(new)} "
    if text.count(old_class) != 1:
        fail(f"{formula}: expected one `{old_class.strip()}`, found {text.count(old_class)}")
    return new_path, text.replace(old_class, new_class)


def _jadx_reference_updates(old: str, new: str) -> dict[str, str]:
    """Return the updated rea.rb, README.md and CI content, without writing.

    `jadx-headless-mcp@<release>` appears in rea.rb (header table, depends_on,
    caveats, test), README (pin table, install commands, sections) and CI
    (audit/install/test lists, REA_JADX_MCP_JAR, doctor version check).
    """
    updates: dict[str, str] = {}

    rea = read(REA_FORMULA)
    rea, count = re.subn(
        r"(#\s+jadx-headless-mcp@)\S+(\s+)\S+(\s+src/android/JadxRelease\.ts)",
        lambda match: f"{match.group(1)}{new}{match.group(2)}{new}{match.group(3)}",
        rea,
    )
    if count != 1:
        fail(f"{REA_FORMULA}: expected one jadx pin line, found {count}")
    if f"jadx-headless-mcp@{old}" not in rea:
        fail(f"{REA_FORMULA}: no references to jadx-headless-mcp@{old} left to update")
    updates[REA_FORMULA] = rea.replace(
        f"jadx-headless-mcp@{old}", f"jadx-headless-mcp@{new}"
    )

    readme = read("README.md")
    readme, count = re.subn(
        r"(\| `jadx-headless-mcp@)[^`]+`(\s+\| )\S+( \| `src/android/JadxRelease\.ts` \|)",
        lambda match: f"{match.group(1)}{new}`{match.group(2)}{new}{match.group(3)}",
        readme,
    )
    if count != 1:
        fail(f"README.md: expected one jadx pin row, found {count}")
    if f"jadx-headless-mcp@{old}" not in readme:
        fail(f"README.md: no references to jadx-headless-mcp@{old} left to update")
    updates["README.md"] = readme.replace(
        f"jadx-headless-mcp@{old}", f"jadx-headless-mcp@{new}"
    )

    ci = read(CI_WORKFLOW)
    if f'("jadx", "{old}")' not in ci:
        fail(f"{CI_WORKFLOW}: expected the jadx doctor pin {old}, found none")
    if f"jadx-headless-mcp@{old}" not in ci:
        fail(f"{CI_WORKFLOW}: no references to jadx-headless-mcp@{old} left to update")
    ci = ci.replace(f'("jadx", "{old}")', f'("jadx", "{new}")')
    updates[CI_WORKFLOW] = ci.replace(
        f"jadx-headless-mcp@{old}", f"jadx-headless-mcp@{new}"
    )
    return updates


def _kuna_reference_updates(old: str, new: str) -> dict[str, str]:
    """Return the updated rea.rb, README.md and CI content, without writing.

    `kuna@<release>` appears in rea.rb (header table, depends_on, caveats, test),
    README (pin table, install commands, section) and CI (audit/install/test
    lists, REA_KUNA_COMMAND, doctor version check).
    """
    updates: dict[str, str] = {}

    rea = read(REA_FORMULA)
    rea, count = re.subn(
        r"(#\s+kuna@)\S+(\s+)\S+(\s+src/kuna/KunaRelease\.ts)",
        lambda match: f"{match.group(1)}{new}{match.group(2)}{new}{match.group(3)}",
        rea,
    )
    if count != 1:
        fail(f"{REA_FORMULA}: expected one kuna pin line, found {count}")
    if f"kuna@{old}" not in rea or f'assert_match "kuna {old}"' not in rea:
        fail(f"{REA_FORMULA}: no references to kuna@{old} left to update")
    rea = rea.replace(f"kuna@{old}", f"kuna@{new}")
    rea = rea.replace(f'assert_match "kuna {old}"', f'assert_match "kuna {new}"')
    updates[REA_FORMULA] = rea

    readme = read("README.md")
    readme, count = re.subn(
        r"(\| `kuna@)[^`]+`(\s+\| )\S+( \| `src/kuna/KunaRelease\.ts` \|)",
        lambda match: f"{match.group(1)}{new}`{match.group(2)}{new}{match.group(3)}",
        readme,
    )
    if count != 1:
        fail(f"README.md: expected one kuna pin row, found {count}")
    if f"kuna@{old}" not in readme:
        fail(f"README.md: no references to kuna@{old} left to update")
    updates["README.md"] = readme.replace(f"kuna@{old}", f"kuna@{new}")

    ci = read(CI_WORKFLOW)
    if f'("kuna-installation", "{old}")' not in ci:
        fail(f"{CI_WORKFLOW}: expected the kuna-installation pin {old}, found none")
    if f"kuna@{old}" not in ci:
        fail(f"{CI_WORKFLOW}: no references to kuna@{old} left to update")
    ci = ci.replace(f'("kuna-installation", "{old}")', f'("kuna-installation", "{new}")')
    updates[CI_WORKFLOW] = ci.replace(f"kuna@{old}", f"kuna@{new}")
    return updates


def _rewrite_jadx_urls(text: str, formula: str, version: str, shas: dict[str, str]) -> str:
    asset = f"jadx-headless-mcp-{version}-all.jar"
    text, count = re.subn(
        r"https://github\.com/"
        + re.escape(JADX_REPO)
        + r"/releases/download/v[^\"/]+/jadx-headless-mcp-[^\"/]+-all\.jar",
        f"https://github.com/{JADX_REPO}/releases/download/v{version}/{asset}",
        text,
    )
    if count != 1:
        fail(f"{formula}: expected one release JAR URL, found {count}")
    return replace_sha_after_url(text, asset, shas[asset], formula)


def _rewrite_kuna_urls(text: str, formula: str, version: str, shas: dict[str, str]) -> str:
    for platform in KUNA_PLATFORMS:
        asset = f"kuna-v{version}-{platform}.tar.gz"
        text, count = re.subn(
            r"https://github\.com/"
            + re.escape(KUNA_REPO)
            + r"/releases/download/v[^\"/]+/kuna-v[^\"/]+-"
            + re.escape(platform)
            + r"\.tar\.gz",
            f"https://github.com/{KUNA_REPO}/releases/download/v{version}/{asset}",
            text,
        )
        if count != 1:
            fail(f"{formula}: expected one {platform} URL, found {count}")
        text = replace_sha_after_url(text, asset, shas[asset], formula)
    return text


def _install_versioned_keg(
    *,
    glob: str,
    prefix: str,
    class_prefix: str,
    pin_regex: str,
    version: str,
    repo: str,
    assets: list[str],
    reference_updates,
    rewrite_urls,
) -> None:
    """Re-pin one versioned keg, renaming it when the pin moves.

    Assets and checksums are resolved before the tree is touched, and the new
    formula content plus the rea.rb/README/CI references are computed in memory
    first, so a failed download or a stale reference pattern leaves the checkout
    unchanged.
    """
    formula = _versioned_formula(glob)
    current = pinned_version(read(formula), pin_regex, formula)
    shas = {asset: asset_sha256(repo, f"v{version}", asset) for asset in assets}

    new_path = pathlib.Path(formula)
    renamed_text: str | None = None
    updates: dict[str, str] = {}
    if current != version:
        new_path, renamed_text = _renamed_versioned_formula(
            formula, prefix, class_prefix, current, version
        )
        updates = reference_updates(current, version)

    text = renamed_text if renamed_text is not None else read(formula)
    text = rewrite_urls(text, formula, version, shas)

    if renamed_text is not None:
        for path, content in updates.items():
            write(path, content)
        new_path.write_text(text, encoding="utf-8")
        pathlib.Path(formula).unlink()
    else:
        write(formula, text)


def pin_jadx(version: str) -> None:
    _install_versioned_keg(
        glob=JADX_KEG_GLOB,
        prefix=JADX_FORMULA_PREFIX,
        class_prefix="JadxHeadlessMcpAT",
        pin_regex=r'jadx-headless-mcp-([^/"]+)-all\.jar',
        version=version,
        repo=JADX_REPO,
        assets=[f"jadx-headless-mcp-{version}-all.jar"],
        reference_updates=_jadx_reference_updates,
        rewrite_urls=_rewrite_jadx_urls,
    )


def pin_kuna(version: str) -> None:
    _install_versioned_keg(
        glob=KUNA_KEG_GLOB,
        prefix=KUNA_FORMULA_PREFIX,
        class_prefix="KunaAT",
        pin_regex=r'kuna-v([^/"]+)-macos-arm64\.tar\.gz',
        version=version,
        repo=KUNA_REPO,
        assets=[f"kuna-v{version}-{platform}.tar.gz" for platform in KUNA_PLATFORMS],
        reference_updates=_kuna_reference_updates,
        rewrite_urls=_rewrite_kuna_urls,
    )


def _check_pins(rea_version: str, pins: dict[str, str], *, commit_body: bool = True) -> bool:
    """Compare the tap's engine pins with the ones a REA release verifies.

    Agreement lines go to stdout, which the bump workflow commits as the bump
    message's body, only when `commit_body` is set: the bump passes it when this
    run moved the rea pin, because only then do the lines describe a change the
    commit makes. Otherwise they are job-log status on stderr, like the
    `already at` lines, and a package that disagrees is always a job-log error
    because a disagreement fails the run before anything is committed.
    """
    stream = sys.stdout if commit_body else sys.stderr
    rows = (
        ("rea", rea_version, rea_version),
        ("rea-full", _rea_full_pin(), rea_version),
        ("jadx-headless-mcp", _jadx_pin(), pins["jadx-headless-mcp"]),
        ("kuna", _kuna_pin(), pins["kuna"]),
        ("ghidra", _ghidra_pin(), pins["ghidra"]),
    )
    agreed = True
    for package, pinned, verified in rows:
        if pinned == verified:
            print(f"{package}: {pinned} (matches REA {rea_version})", file=stream)
            continue
        agreed = False
        print(f"{package}: {pinned} but REA {rea_version} verifies {verified}", file=sys.stderr)
    return agreed


def check() -> None:
    rea_version = _rea_pin()
    pins = _engine_pins(_tag_for_version(rea_version))
    if _check_pins(rea_version, pins):
        return
    fail(
        "the tap no longer matches the engines REA verifies; run "
        f"`python3 scripts/bump/rea.py` to re-pin the jadx-headless-mcp@"
        f"{pins['jadx-headless-mcp']} and kuna@{pins['kuna']} kegs and rea-full "
        "with rea, and update the Ghidra keg (plus ghidra-mcp) by hand when "
        "REA's verified Ghidra release moves"
    )


def main() -> None:
    tag = latest_tag(REPO)
    if not tag.startswith(TAG_PREFIX):
        tag = _tag_for_version(tag.lstrip("v"))
    version = _version_from_tag(tag)
    pins = _engine_pins(tag)

    current_rea = _rea_pin()
    current_rea_full = _rea_full_pin()
    current_jadx = _jadx_pin()
    current_kuna = _kuna_pin()
    current_ghidra = _ghidra_pin()

    # Fail before writing anything: a Ghidra move also needs a new Ghidra keg
    # and a matching GhidraMCP build, which this script cannot produce.
    if current_ghidra != pins["ghidra"]:
        fail(
            f"REA {version} verifies Ghidra {pins['ghidra']}, but the tap pins "
            f"{current_ghidra} in {GHIDRA_FORMULA}. Update the Ghidra keg and "
            f"Formula/ghidra-mcp.rb by hand (a Ghidra release needs its own native "
            f"build and an extension built for it), then re-run this bump."
        )

    if current_jadx != pins["jadx-headless-mcp"]:
        pin_jadx(pins["jadx-headless-mcp"])
    report("jadx-headless-mcp", current_jadx, pins["jadx-headless-mcp"])

    if current_kuna != pins["kuna"]:
        pin_kuna(pins["kuna"])
    report("kuna", current_kuna, pins["kuna"])

    # The pin matrix is the commit's evidence only when this run moved rea (or
    # the rea-full variant that mirrors it): an unrelated bump (say gbrain)
    # still runs this script and would otherwise decorate its commit message
    # with five `matches REA` lines it never touched.
    rea_moved = current_rea != version or current_rea_full != version
    if rea_moved:
        pin_rea(version)
    report("rea", current_rea, version)
    report("rea-full", current_rea_full, version)

    if not _check_pins(version, pins, commit_body=rea_moved):
        fail("the re-pinned formulae still disagree with the REA release")


if __name__ == "__main__":
    if "--check" in sys.argv[1:]:
        check()
    else:
        main()
