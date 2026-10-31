# fmu/homebrew

Homebrew formulae and casks for [fmu](https://github.com/fmu)'s tools, plus a
few apps that homebrew-cask cannot carry. Most packages are re-pinned to
upstream's latest release automatically; see [Upstream bumps](#upstream-bumps).

```bash
# This tap is a multi-formula repository named `homebrew`, so Homebrew cannot
# derive its URL from `user/repo`; pass the URL explicitly (one time).
brew tap fmu/homebrew https://github.com/fmu/homebrew.git

# Homebrew 5+ keeps third-party taps untrusted until they are named.
brew trust fmu/homebrew
```

Then install what you want:

```bash
brew install gbrain gbrain-embed
brew install --cask iqualize mornye mpv-app
```

## Formulae

### gbrain

[GBrain](https://github.com/garrytan/gbrain) — Postgres-native personal
knowledge brain with hybrid RAG search. The formula installs upstream's
self-contained binary; it is not the unrelated npm `gbrain` package.

```bash
brew install gbrain
gbrain init --pglite
gbrain doctor
```

Upstream publishes binaries for macOS arm64 and Linux x86_64 only.

The formula does not wrap or disable gbrain's own updater: `gbrain upgrade`
replaces the binary in the Homebrew keg in place. The scheduled bump keeps the
formula on the latest upstream release, so `brew update && brew upgrade gbrain`
tracks upstream as well. In-place self-update needs a user-writable Homebrew
prefix.

### gbrain-embed

On-demand local embeddings for [gbrain](https://github.com/garrytan/gbrain),
served by [llama.cpp](https://github.com/ggml-org/llama.cpp). It runs a loopback
OpenAI-compatible endpoint, starts `llama-server` on the first embedding
request, and stops it again after an idle window, so the model is resident only
while it is in use.

```bash
brew install gbrain-embed
```

The formula depends on `bun` and `llama.cpp` from Homebrew; there are no Nix
dependencies. It needs the `gbrain` CLI on `PATH`; install it from this same tap
(`brew install gbrain`) or use your existing installation.

Post-install, once:

```bash
gbrain-embed model install      # 3.3 GB GGUF, SHA-256 verified
gbrain-embed setup              # configure gbrain and backfill
brew services start gbrain-embed
```

`brew services` keeps `gbrain-embed serve` running at login; `gbrain-embed
status`, `gbrain-embed mode throughput`, and `gbrain-embed bench` work against
it. Upgrading (`brew upgrade gbrain-embed`) replaces the code but not the model
or `~/.config/gbrain-embed/config.json`.

Uninstall:

```bash
brew services stop gbrain-embed
brew uninstall gbrain-embed
```

The formula tracks the tagged source release of
[fmu/gbrain-embed](https://github.com/fmu/gbrain-embed) and is bumped by hand
when that repository is tagged.

### pared

The CLI half of [Pared](https://github.com/4evy/pared); the app is the
`pared-app` cask below. Upstream's own formula builds from source and requires
Xcode 27, so this tap pins the released tarball instead. Both artifacts come
from the same tag and are re-pinned together.

```bash
brew install fmu/homebrew/pared
```

The release is Apple silicon and macOS 27 only, and the formula declares that
floor, so installing it on an older host fails instead of producing a binary
that cannot start.

### ghidra@12.1

Ghidra 12.1.4, pinned. Homebrew core has moved on to 12.2; this keg stays on
12.1.4 for extensions that are built against that exact release, because
Ghidra's extension loader does not reject a version mismatch at startup — an
API move only shows up later as a `NoClassDefFoundError` inside the affected
tool.

```bash
brew install fmu/homebrew/ghidra@12.1
```

It is keg-only, so it coexists with core's `ghidra` without either formula
owning `/opt/homebrew/bin/ghidraRun`. The public release archive ships native
components for Windows and Linux only, so the formula also compiles the macOS
native components (the decompiler, Sleigh and the demangler) with the archive's
documented `support/gradle/gradlew buildNatives` run. That needs the formula's
JDK 21 and network access for the Gradle wrapper's first download.

This is the one package the scheduled bump does not touch: the pin is the point.
Bump it by hand, together with the tooling that is built against the same
Ghidra version.

## Casks

None of these casks is in homebrew-cask. `iqualize` is simply not shipped there;
the other three fail homebrew-cask's notarization requirement, and their casks
carry the one-time Gatekeeper workaround as a caveat.

### iqualize

[iQualize](https://iqualize.app/) is a system-wide parametric EQ: it taps system
audio with Core Audio Taps and applies the curve before the audio reaches the
output device, so it needs no virtual audio driver. It is Developer ID signed
and notarized, so unlike the other apps here it carries no Gatekeeper caveat.

The app installs its own `iqualize` CLI into `/usr/local/bin` (Settings >
General > "Install Command Line Tool"), so the cask deliberately adds no
`binary` stanza: a Homebrew-owned copy would shadow the app's own and drift from
it on upgrade. There is no in-app updater, so `brew upgrade` is the only route
to a new version.

### mornye

[Mornye](https://desktop.mornye.com) is a music library player with synced
lyrics and tag editing. The release is ad-hoc signed and not notarized, so
Homebrew quarantines it and Gatekeeper blocks the first launch; the caveat says
how to approve it once.

The app ships its own updater (`auto_updates true`), so `brew upgrade` defers to
it, and downloads its music to `~/Downloads/Mornye` — user data that `zap`
leaves alone.

### mpv-app

The **first-party** mpv app bundle, built by mpv's own CI and linked from
<https://mpv.io/installation/> under "First-party builds". mpv has no notarized
macOS distribution: the `mpv` formula is CLI-only by design, and the
third-party cask was disabled in homebrew-cask for failing the Gatekeeper check.

The cask tracks the latest **stable** release, not the rolling `git-release`
tag: that tag is rebuilt on every push to master and its assets are replaced,
so a pinned cask URL would 404 within a day. It publishes one asset per macOS
version and architecture, and the cask selects the matching one per host.

The cask also links the bundle's own binary as `mpv` on `PATH`; the `mpv` formula
must not be installed next to it. The linked binary sits outside the bundle, so
the bundled Vulkan loader cannot find its MoltenVK ICD from it — launch the app
for `vo=gpu-next`, or point `VK_ICD_FILENAMES` at the bundled ICD.

### pared-app

[Pared](https://github.com/4evy/pared) chooses which Apple Intelligence features
stay on a Mac and removes the downloaded models of the ones that do not. The
app is ad-hoc signed and not notarized, so it lives here with a caveat. It
carries Sparkle (`auto_updates true`), so `brew upgrade` defers to the app's own
updater. Like the formula, it is Apple silicon and macOS 27 only.

The bundle contains a copy of the CLI, but the cask has no `binary` stanza on
purpose: `fmu/homebrew/pared` is the CLI's Homebrew route, and a second
Homebrew-owned `pared` would shadow it.

## Upstream bumps

[`bump-upstream.yml`](.github/workflows/bump-upstream.yml) re-pins the tap's
packages every 30 minutes. For each package, [`scripts/bump/`](scripts/bump/)
resolves upstream's latest release tag, downloads the release asset(s), computes
their SHA-256, rewrites the version and checksums, and — when something moved —
commits, pushes and dispatches the macOS CI run.

| package | upstream | release tag |
| --- | --- | --- |
| `gbrain` | `garrytan/gbrain` | `v*` |
| `iqualize` | `dariuscorvus/iqualize` | `v*` |
| `mornye` | `mornyeapp/Mornye-Desktop` | `v*` |
| `mpv-app` | `mpv-player/mpv` | `v*` (stable) |
| `pared` + `pared-app` | `4evy/pared` | no `v` prefix |

`ghidra@12.1` is deliberately excluded (see above), and `gbrain-embed` follows
a hand-made tag of `fmu/gbrain-embed` rather than a GitHub release.

A manual run can pin a specific tag for one package:

```bash
gh workflow run bump-upstream.yml -f package=mornye -f tag=v5.2.6
```

Bump scripts can also be run locally; they need only `python3` and, for the
GitHub API, an optional `GH_TOKEN`:

```bash
python3 scripts/bump/mornye.py            # latest upstream release
RELEASE_TAG=v5.2.6 python3 scripts/bump/mornye.py   # a specific tag
```

## Development

Formulae are under `Formula/` and casks under `Casks/`; both are plain Ruby
files. [`ci.yml`](.github/workflows/ci.yml) audits every formula and cask on the
latest macOS, installs the packages the runner can run, and runs the formula
tests. The two Apple silicon/macOS 27 artifacts are only installed when the
runner is new enough.

To validate a change locally before pushing:

```bash
brew tap fmu/homebrew file://"$PWD"
brew audit --strict fmu/homebrew/gbrain fmu/homebrew/gbrain-embed \
  fmu/homebrew/pared fmu/homebrew/ghidra@12.1
brew audit --strict --cask fmu/homebrew/iqualize fmu/homebrew/mornye \
  fmu/homebrew/mpv-app fmu/homebrew/pared-app
```
