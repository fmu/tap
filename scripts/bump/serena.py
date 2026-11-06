#!/usr/bin/env python3
"""Pin Formula/serena.rb to the latest oraios/serena release.

Serena tags every release in oraios/serena, and the repository carries the
``uv.lock`` that upstream tests against. The formula installation itself is the
tag's source tree; the Python dependency set is not resolved fresh here, because
a fresh resolution could pick a different transitive set than the one upstream
locked and than the exact security pins in pyproject.toml describe.

This script therefore walks the release's ``uv.lock`` for the interpreter and
platform the formula targets (CPython 3.14, macOS arm64), prefers the published
wheel for each package, and falls back to the sdist only where no compatible
wheel exists (that one is then built by pip). Version, tag and commit revision
come from GitHub; the dependency block is generated between marker comments in
the formula, which are the only part of it this script owns.

It fails instead of writing a formula when the tag cannot be resolved, when
upstream's lock no longer supports Python 3.14, when the lock's own version
disagrees with the tag, or when a package has neither a compatible wheel nor an
sdist. A failed bump must not silently produce an uninstallable formula.
"""

from __future__ import annotations

import json
import os
import re
import tomllib
import urllib.error
import urllib.request

from _common import (
    USER_AGENT,
    drop_bottle_block,
    fail,
    latest_tag,
    pinned_version,
    raw_file,
    read,
    report,
    version_from_tag,
    write,
)

REPO = "oraios/serena"
PYPI_PROJECT = "serena-agent"
FORMULA = "Formula/serena.rb"
LOCKFILE = "uv.lock"

# The formula installs python@3.14 (and macOS arm64 wheels); serena's
# requires-python is >=3.11,<3.15, so 3.14 is the newest supported interpreter
# Homebrew packages. Keep these in step with the depends_on line in the formula.
TARGET_PYTHON = "3.14"
TARGET_PYTHON_FULL = "3.14.10"

_TARGET_ENV = {
    "python_full_version": TARGET_PYTHON_FULL,
    "python_version": TARGET_PYTHON,
    "sys_platform": "darwin",
    "platform_system": "Darwin",
    "platform_machine": "arm64",
    "implementation_name": "cpython",
    "platform_python_implementation": "CPython",
    "os_name": "posix",
    "extra": "",
}

_URL_BLOCK = re.compile(
    r'(?m)^  url "https://github\.com/oraios/serena\.git",\n'
    r'      tag:      "v[^"]+",\n'
    r'      revision: "[0-9a-f]{40}"$'
)
_TAG = r'(?m)^      tag:      "v([^"]+)",$'
_BEGIN = "  # BEGIN GENERATED PYPI RESOURCES (scripts/bump/serena.py)\n"
_END = "  # END GENERATED PYPI RESOURCES\n"

_WHEEL = re.compile(r"^(?P<name>[^-]+)-(?P<version>[^-]+)(?:-[^-]+)?-(?P<py>[^-]+)-(?P<abi>[^-]+)-(?P<plat>[^-]+)\.whl$")

_MARKER_TOKEN = re.compile(
    r"""\s*(?:
        (?P<op>===|==|!=|<=|>=|~=|<|>)
      | (?P<string>'[^']*'|"[^"]*")
      | (?P<name>[A-Za-z_][A-Za-z0-9_]*)
      | (?P<lparen>\()
      | (?P<rparen>\))
    )""",
    re.VERBOSE,
)


def _github_json(url: str) -> dict:
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


def _commit_for_tag(tag: str) -> str:
    """Resolve the commit a release tag points at, for the formula's revision."""
    body = _github_json(f"https://api.github.com/repos/{REPO}/commits/{tag}")
    sha = body.get("sha")
    if not isinstance(sha, str) or not re.fullmatch(r"[0-9a-f]{40}", sha):
        fail(f"{REPO} tag {tag!r} did not resolve to a commit")
    return sha


def _version_tuple(value: str) -> tuple[int, ...] | None:
    if not re.fullmatch(r"\d+(?:\.\d+)*", value):
        return None
    return tuple(int(part) for part in value.split("."))


def _compare_versions(left: str, op: str, right: str) -> bool:
    left_version = _version_tuple(left)
    right_version = _version_tuple(right)
    if left_version is None or right_version is None:
        fail(f"cannot order non-version values {left!r} and {right!r} in the release's uv.lock")
    size = max(len(left_version), len(right_version))
    left_version += (0,) * (size - len(left_version))
    right_version += (0,) * (size - len(right_version))
    if op == "<":
        return left_version < right_version
    if op == "<=":
        return left_version <= right_version
    if op == ">":
        return left_version > right_version
    if op == ">=":
        return left_version >= right_version
    raise AssertionError(op)


def _allows_python(requires: str, version: str) -> bool:
    """Whether a requires-python string admits the interpreter the formula installs."""
    for clause in requires.split(","):
        clause = clause.strip()
        if not clause:
            continue
        match = re.fullmatch(r"(===|==|!=|<=|>=|~=|<|>)\s*(\d+(?:\.\d+)*)", clause)
        if match is None:
            fail(f"unsupported requires-python clause {clause!r}; update scripts/bump/serena.py")
        op, spec = match.groups()
        if op in ("==", "==="):
            ok = version == spec
        elif op == "!=":
            ok = version != spec
        elif op == "~=":
            prefix = spec.rsplit(".", 1)[0]
            ok = _compare_versions(version, ">=", spec) and version.startswith(prefix + ".")
        else:
            ok = _compare_versions(version, op, spec)
        if not ok:
            return False
    return True


def _tokenize_marker(marker: str) -> list[tuple[str, str]]:
    tokens: list[tuple[str, str]] = []
    position = 0
    while position < len(marker):
        match = _MARKER_TOKEN.match(marker, position)
        if match is None:
            if marker[position:].strip() == "":
                break
            fail(f"cannot parse marker {marker!r} at {marker[position:]!r}")
        tokens.append((match.lastgroup or "", match.group(match.lastgroup or "")))
        position = match.end()
    return tokens


class _MarkerParser:
    def __init__(self, marker: str, extra: str) -> None:
        self.marker = marker
        self.extra = extra
        self.tokens = _tokenize_marker(marker)
        self.position = 0

    def parse(self) -> bool:
        value = self._parse_or()
        if self.position != len(self.tokens):
            fail(f"marker {self.marker!r} has trailing tokens")
        return value

    def _parse_or(self) -> bool:
        value = self._parse_and()
        while self._accept_word("or"):
            value = self._parse_and() or value
        return value

    def _parse_and(self) -> bool:
        value = self._parse_unary()
        while self._accept_word("and"):
            value = self._parse_unary() and value
        return value

    def _parse_unary(self) -> bool:
        if self._accept_word("not"):
            return not self._parse_unary()
        return self._parse_atom()

    def _parse_atom(self) -> bool:
        if self._accept_kind("lparen"):
            value = self._parse_or()
            if not self._accept_kind("rparen"):
                fail(f"marker {self.marker!r} has an unclosed parenthesis")
            return value
        return self._parse_comparison()

    def _parse_comparison(self) -> bool:
        left = self._parse_operand()
        operator = self._parse_operator()
        right = self._parse_operand()
        return self._compare(left, operator, right)

    def _parse_operand(self) -> str:
        if self.position >= len(self.tokens):
            fail(f"marker {self.marker!r} ends before an operand")
        kind, value = self.tokens[self.position]
        self.position += 1
        if kind == "string":
            return value[1:-1]
        if kind == "name":
            if value == "extra":
                return self.extra
            if value in _TARGET_ENV:
                return _TARGET_ENV[value]
            fail(f"marker {self.marker!r} uses unsupported variable {value!r}; update scripts/bump/serena.py")
        fail(f"marker {self.marker!r} has unexpected token {value!r}")

    def _parse_operator(self) -> str:
        if self.position >= len(self.tokens):
            fail(f"marker {self.marker!r} has no comparison operator")
        kind, value = self.tokens[self.position]
        if kind == "op":
            self.position += 1
            return value
        if kind == "name" and value == "in":
            self.position += 1
            return "in"
        if kind == "name" and value == "not":
            if self.position + 1 < len(self.tokens) and self.tokens[self.position + 1] == ("name", "in"):
                self.position += 2
                return "not in"
        fail(f"marker {self.marker!r} has unexpected operator {value!r}")

    def _compare(self, left: str, operator: str, right: str) -> bool:
        if operator in ("in", "not in"):
            value = left in right
            return value if operator == "in" else not value
        if operator == "~=":
            prefix = right.rsplit(".", 1)[0]
            return left == prefix or (left.startswith(prefix + ".") and _compare_versions(left, ">=", right))
        if operator in ("==", "!="):
            if right.endswith(".*"):
                prefix = right[:-2]
                value = left == prefix or left.startswith(prefix + ".")
            else:
                value = left == right
            return value if operator == "==" else not value
        if operator == "===":
            return left == right
        return _compare_versions(left, operator, right)

    def _accept_word(self, word: str) -> bool:
        if self.position < len(self.tokens) and self.tokens[self.position] == ("name", word):
            self.position += 1
            return True
        return False

    def _accept_kind(self, kind: str) -> bool:
        if self.position < len(self.tokens) and self.tokens[self.position][0] == kind:
            self.position += 1
            return True
        return False


def _marker_matches(marker: str, extra: str = "") -> bool:
    return _MarkerParser(marker, extra).parse()


def _wheel_score(url: str) -> tuple[int, int, int] | None:
    """Rank a wheel for CPython 3.14 on macOS arm64, or None if incompatible."""
    filename = url.rsplit("/", 1)[-1]
    match = _WHEEL.match(filename)
    if match is None:
        return None
    python_tags = match["py"].split(".")
    abi = match["abi"]
    if any(tag.startswith("cp3") and tag.endswith("t") for tag in python_tags) or abi.startswith("cp3") and abi.endswith("t"):
        return None  # free-threaded builds are a different ABI
    if "cp314" in python_tags and abi in ("cp314", "abi3", "none"):
        interpreter = (4, 314) if abi == "cp314" else (3, 314)
    elif abi == "abi3":
        versions = [int(tag[2:]) for tag in python_tags if re.fullmatch(r"cp3\d+", tag)]
        if not versions or max(versions) > 314:
            return None
        interpreter = (2, max(versions))
    elif "py3" in python_tags and abi == "none":
        interpreter = (1, 0)
    else:
        return None
    platforms = match["plat"].split(".")
    if "any" in platforms:
        platform = 0
    elif any(tag.startswith("macosx_") and tag.endswith("_arm64") for tag in platforms):
        platform = 2
    elif any(tag.startswith("macosx_") and tag.endswith("_universal2") for tag in platforms):
        platform = 1
    else:
        return None
    return (interpreter[0], interpreter[1], platform)


def _wheel_for(package: dict) -> dict | None:
    best: tuple[tuple[int, int, int], str, dict] | None = None
    for wheel in package.get("wheels") or []:
        url = wheel.get("url")
        if not isinstance(url, str):
            continue
        score = _wheel_score(url)
        if score is None:
            continue
        candidate = (score, url, wheel)
        if best is None or candidate[0] > best[0] or (candidate[0] == best[0] and url < best[1]):
            best = candidate
    return best[2] if best else None


def _resolve_dependency(by_name: dict[str, list[dict]], dependency: dict) -> dict:
    name = dependency.get("name")
    candidates = by_name.get(name)
    if not candidates:
        fail(f"{LOCKFILE}: no package entry for {name!r}")
    if dependency.get("version"):
        candidates = [package for package in candidates if package.get("version") == dependency["version"]]
    if dependency.get("source"):
        candidates = [package for package in candidates if package.get("source") == dependency["source"]]
    if len(candidates) > 1:
        candidates = [
            package
            for package in candidates
            if not package.get("resolution-markers")
            or any(_marker_matches(marker) for marker in package["resolution-markers"])
        ]
    if len(candidates) != 1:
        fail(
            f"{LOCKFILE}: cannot resolve {dependency!r} for {TARGET_PYTHON} on macOS arm64 "
            f"(candidates: {[(p.get('name'), p.get('version')) for p in candidates]})"
        )
    return candidates[0]


def _dependency_closure(lock: dict, version: str) -> dict[tuple[str, str], dict]:
    packages = lock.get("package")
    if not isinstance(packages, list):
        fail(f"{LOCKFILE}: no [[package]] entries")
    by_name: dict[str, list[dict]] = {}
    for package in packages:
        by_name.setdefault(package["name"], []).append(package)

    root = next(
        (
            package
            for package in by_name.get(PYPI_PROJECT, [])
            if (package.get("source") or {}).get("editable") and package.get("version") == version
        ),
        None,
    )
    if root is None:
        fail(f"{REPO} v{version}: {LOCKFILE} does not contain an editable {PYPI_PROJECT} {version}")

    selected: dict[tuple[str, str], dict] = {}
    pending = [root]
    while pending:
        package = pending.pop()
        key = (package["name"], package["version"])
        if key in selected:
            continue
        selected[key] = package
        for dependency in package.get("dependencies") or []:
            if dependency.get("marker") and not _marker_matches(dependency["marker"]):
                continue
            target = _resolve_dependency(by_name, dependency)
            pending.append(target)
            for extra in dependency.get("extra") or []:
                for optional in (target.get("optional-dependencies") or {}).get(extra, []):
                    if optional.get("marker") and not _marker_matches(optional["marker"], extra=extra):
                        continue
                    pending.append(_resolve_dependency(by_name, optional))
    return selected


def _resource_entries(lock: dict, version: str) -> list[dict]:
    selected = _dependency_closure(lock, version)
    entries: list[dict] = []
    for (name, _package_version), package in sorted(selected.items()):
        if (package.get("source") or {}).get("editable"):
            continue
        wheel = _wheel_for(package)
        if wheel is None:
            sdist = package.get("sdist") or {}
            if not sdist.get("url") or not sdist.get("hash"):
                fail(
                    f"{name} {package['version']}: no wheel for CPython {TARGET_PYTHON} on macOS arm64 "
                    f"and no sdist; {FORMULA} cannot be installed"
                )
            entries.append(
                {
                    "name": name,
                    "url": sdist["url"],
                    "sha256": sdist["hash"].removeprefix("sha256:"),
                    "note": f"{name} publishes no wheel for this interpreter/platform; built from sdist",
                }
            )
            continue
        entries.append({"name": name, "url": wheel["url"], "sha256": wheel["hash"].removeprefix("sha256:")})

    for entry in entries:
        if not entry["url"].startswith("https://files.pythonhosted.org/"):
            fail(f"{entry['name']}: unexpected resource URL {entry['url']}")
        if not re.fullmatch(r"[0-9a-f]{64}", entry["sha256"]):
            fail(f"{entry['name']}: uv.lock has no usable sha256")
    if len(entries) < 50:
        fail(f"{LOCKFILE}: only {len(entries)} runtime packages resolved; refusing to pin a truncated dependency set")
    return entries


def _render_resources(entries: list[dict]) -> str:
    lines = [_BEGIN]
    for entry in entries:
        if entry.get("note"):
            lines.append(f'  # {entry["note"]}\n')
        lines.extend(
            [
                f'  resource "{entry["name"]}" do\n',
                f'    url "{entry["url"]}"\n',
                f'    sha256 "{entry["sha256"]}"\n',
                "  end\n",
                "\n",
            ]
        )
    lines.append(_END)
    return "".join(lines)


def _replace_resources(text: str, entries: list[dict]) -> str:
    start = text.find(_BEGIN)
    end = text.find(_END)
    if start == -1 or end == -1 or end < start:
        fail(f"{FORMULA}: generated-resource markers not found")
    return text[:start] + _render_resources(entries) + text[end + len(_END) :]


def main() -> None:
    tag = latest_tag(REPO)
    version = version_from_tag(tag)
    text = read(FORMULA)
    pinned = pinned_version(text, _TAG, FORMULA)
    if pinned == version:
        report("serena", pinned, version)
        return

    revision = _commit_for_tag(tag)
    lock_text = raw_file(REPO, tag, LOCKFILE)
    try:
        lock = tomllib.loads(lock_text)
    except tomllib.TOMLDecodeError as exc:
        fail(f"{LOCKFILE} at {tag} is not valid TOML: {exc}")

    requires = lock.get("requires-python")
    if not isinstance(requires, str):
        fail(f"{LOCKFILE} at {tag} has no requires-python")
    if not _allows_python(requires, TARGET_PYTHON_FULL):
        fail(
            f"{REPO} {tag} requires Python {requires!r}, which excludes the formula's "
            f"python@{TARGET_PYTHON}; update the depends_on line and the target in scripts/bump/serena.py"
        )

    entries = _resource_entries(lock, version)

    text, count = _URL_BLOCK.subn(
        f'  url "https://github.com/{REPO}.git",\n'
        f'      tag:      "{tag}",\n'
        f'      revision: "{revision}"',
        text,
    )
    if count != 1:
        fail(f"{FORMULA}: expected one Git tag url block, found {count}")
    text = drop_bottle_block(text, FORMULA)
    text = _replace_resources(text, entries)

    write(FORMULA, text)
    report("serena", pinned, version)


if __name__ == "__main__":
    main()
