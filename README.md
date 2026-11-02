# fmu/tap

Homebrew formulae and casks for [fmu](https://github.com/fmu)'s tools, plus a
few apps that homebrew-cask cannot carry. Most packages are re-pinned to
upstream's latest release automatically; the reverse-engineering toolchain is
pinned to the versions [REA](https://github.com/morluto/rea) verifies. See
[Upstream bumps](#upstream-bumps).

```bash
# Homebrew 5+ keeps third-party taps untrusted until they are named.
brew trust fmu/tap
```

Then install what you want. Naming a package with the tap also taps this
repository automatically, so `brew install fmu/tap/rea` works on a machine that
has never tapped it; `brew tap fmu/tap` alone is enough too, since Homebrew
derives the URL from the tap name:

```bash
brew install fmu/tap/rea          # the reverse-engineering MCP server and CLI
brew install fmu/tap/rea-full     # REA plus every integration Homebrew packages
brew install fmu/tap/unblob       # firmware extractor (binwalk, 7z, unar, ...)
brew install fmu/tap/skippy        # standalone model-serving CLI (Apple silicon)
brew install fmu/tap/mesh-llm      # distributed LLM mesh runtime (Apple silicon)
brew install fmu/tap/jadx-headless-mcp  # latest upstream (REA uses the pinned @ keg)
brew install fmu/tap/kuna         # latest upstream (REA uses the pinned @ keg)
brew install fmu/tap/ghidra-mcp   # standalone Ghidra MCP server (independent of rea)
brew install fmu/tap/gbrain fmu/tap/qwen3-embed
brew install fmu/tap/designcraft-cli  # the headless DesignCraft engine (matches the app cask)
brew install fmu/tap/figcraft-cli  # the headless FigCraft engine (matches the app cask)
brew install fmu/tap/solidcraft-cli  # the headless SolidCraft engine (same stream as the app cask)
brew install fmu/tap/vectorcraft-cli  # the headless VectorCraft engine (matches the app cask)
brew install fmu/tap/wordcraft-cli  # the headless WordCraft engine (matches the app cask)
brew install --cask fmu/tap/baocut fmu/tap/iqualize fmu/tap/mornye fmu/tap/mpv-app
```

## Formulae

### rea

[REA](https://github.com/morluto/rea) is one CLI and MCP server that reverse
engineers native, managed, Android and JavaScript targets and keeps the
Evidence of each engine separate. This formula installs the published
`rea-agents` npm package — the same artifact the upstream installer and the
agent plugins use — so `rea doctor`, `rea setup` and `rea mcp` behave exactly
as documented upstream.

```bash
brew install fmu/tap/rea
rea doctor --json
rea setup                       # register agent clients
```

REA is the reference for the rest of the toolchain: each release verifies one
exact release of its engines and reports every other release as unverified, so
the tap pins them together with REA instead of tracking each upstream latest:

| package | pinned | REA source of truth |
| --- | --- | --- |
| `jadx-headless-mcp@0.7.1` | 0.7.1 | `src/android/JadxRelease.ts` |
| `kuna@1.833` | 1.833 | `src/kuna/KunaRelease.ts` |
| `ghidra@12.1` | 12.1.4 | `src/ghidra/GhidraReleasePolicy.ts` |

The formula depends on all three, plus `node` and `openjdk`. `rea` finds its
engines through environment variables; set them once (the caveats print the
same block) and `rea setup` copies the detected values into the agent
registrations it writes:

```bash
export GHIDRA_INSTALL_DIR="$(brew --prefix ghidra@12.1)/libexec"
export REA_KUNA_COMMAND="$(brew --prefix kuna@1.833)/bin/kuna"
export REA_JADX_MCP_JAR="$(brew --prefix jadx-headless-mcp@0.7.1)/libexec/jadx-headless-mcp.jar"
```

Hopper is an optional provider and ships as a cask in homebrew-cask:

```bash
brew install --cask hopper-disassembler
```

Rizin is the other optional integration this tap can supply
(`brew install rizin`, then `REA_RIZIN_COMMAND`); gdb, objdump, apktool,
binwalk, tshark, WABT, sigrok, mitmdump, IDA, JEB and Cutter are detected from
`PATH` or their own `REA_*` setting and are not dependencies of this formula.
`brew install fmu/tap/rea-full` adds the ones Homebrew packages (see below), and
`rea doctor --json` lists each integration with its setting.

Java note: `ghidra@12.1` brings the `openjdk@21` that REA's Ghidra bridge is
verified against, while `openjdk` (latest) serves the JADX bridge. REA picks a
JDK from `JAVA_HOME`, then `PATH`, then Homebrew's `opt/openjdk`; if doctor
complains, export `JAVA_HOME` for `openjdk@21` before `rea setup`.

### rea-full

`rea-full` is the one-command way to get REA with every optional integration
Homebrew can install, so `rea doctor` finds them instead of reporting them
missing. It depends on `rea` and on the formulae below:

| integration | formula | REA setting |
| --- | --- | --- |
| debugger and Cutter bridge | `rizin` | `REA_RIZIN_COMMAND` |
| gdb | `gdb` | `REA_GDB_COMMAND` |
| Android APK unpacking | `apktool` | `REA_APKTOOL_COMMAND` |
| firmware images | `binwalk` | `REA_BINWALK_COMMAND` |
| firmware extraction | `unblob` | `REA_UNBLOB_COMMAND` |
| capture dissection | `wireshark` (`tshark`, `capinfos`) | `REA_TSHARK_COMMAND` |
| WebAssembly | `wabt` (`wasm2wat` …) | `REA_WABT_BIN_DIRECTORY` |
| signal decoding | `sigrok-cli` | `REA_SIGROK_COMMAND` |

`rea` itself brings the pinned engines (`jadx-headless-mcp@0.7.1`,
`kuna@1.833` and `ghidra@12.1`); the standalone `ghidra-mcp` server is not a REA
provider, so it is not part of the bundle.

```bash
brew install fmu/tap/rea-full
rea doctor --json
```

`objdump` needs no dependency: the Command Line Tools' `/usr/bin/objdump` is
what REA looks for by default, and GNU binutils would not do because it is
keg-only and prefixes its tools (`gobjdump`). The remaining providers cannot be
formula dependencies — Hopper, Cutter and mitmproxy are casks, and IDA and JEB
are not in Homebrew at all:

```bash
brew install --cask hopper-disassembler cutter mitmproxy
```

WABT wants an absolute directory rather than a `PATH` entry, so export it once
(the caveats repeat this):

```bash
export REA_WABT_BIN_DIRECTORY="$(brew --prefix wabt)/bin"
```

`rea-full` is pinned with `rea` by `scripts/bump/rea.py`, so the metapackage and
the CLI cannot drift apart.

### unblob

[unblob](https://unblob.org) extracts files from container formats — archive,
compression, filesystem and firmware formats — and is the extractor `rea` drives
through `REA_UNBLOB_COMMAND`. It is not in Homebrew, which is why this tap
packages it.

Upstream publishes prebuilt wheels only: unblob itself is a PyO3/maturin
project and several dependencies (`lief`, `pyperscan`, `cryptography`, `lz4`, …)
are compiled, so the formula installs the published macOS arm64 / CPython 3.14
wheels instead of compiling them. `scripts/bump/unblob.py` resolves the wheel
set from PyPI and pins every URL and SHA-256; `brew upgrade` moves the whole set
with the release.

```bash
brew install fmu/tap/unblob
unblob --version
unblob --show-external-dependencies   # the extractor tools and their status
```

unblob shells out to external extractor tools. The ones Homebrew packages are
dependencies (`p7zip` for `7z`, `unar`, `lzop`, `lziprecover`, `lz4`, `zstd`,
`erofs-utils` for `fsck.erofs`, `simg2img`, `partclone` for
`partclone.restore`, `sasquatch` for SquashFS, and `libmagic` for the Python
bindings). `debugfs` comes from the keg-only `e2fsprogs` formula; the installed
`unblob` is a wrapper that prepends e2fsprogs' sbin (and Homebrew's own sbin)
to `PATH`, so every extractor is found out of the box — `unblob
--show-external-dependencies` should list them all with a ✓.

### sasquatch

[sasquatch](https://github.com/onekey-sec/sasquatch) is ONEKEY's fork of
squashfs-tools with the vendor SquashFS variants that device firmware uses. It
is not in Homebrew; the formula builds the tagged source (upstream's releases
are Debian packages) and installs the binary under both names unblob invokes:
`sasquatch` and `sasquatch-v4be` for big-endian v4 images.

The fork still assumes Linux, so the formula carries a small Darwin patch:
Linux-only headers are guarded, the status thread's `sigtimedwait()` is
emulated with `sigwait()`, and the Linux `l*xattr()` wrappers are mapped onto
Apple's `XATTR_NOFOLLOW` variants.

```bash
brew install fmu/tap/sasquatch
sasquatch -version
```

### partclone

[partclone](https://partclone.org/) backs up and restores the used blocks of a
partition. unblob drives `partclone.restore` to unpack partclone images, so the
formula builds the generic tools only; the filesystem-specific ones
(`partclone.extfs`, `partclone.ntfs`, …) need libraries macOS does not have.

Upstream targets Linux: the Darwin patch guards `linux/fs.h` and `mntent.h`,
uses `getmntinfo()` for the mount check, maps the Linux-only
`O_LARGEFILE`/`O_DIRECT` flags to no-ops, and drops the Linux-only
`ntfsfixboot` helper. The build itself uses the upstream autotools flow, with
`openssl@3` and `zstd` providing the crypto and compressor it links.

```bash
brew install fmu/tap/partclone
partclone.restore --version
```

### skippy

[Skippy](https://github.com/Mesh-LLM/mesh-llm/tree/main/skippy) is Mesh-LLM's
standalone model-serving product: a CLI that manages models and native runtimes,
serves OpenAI- and Anthropic-compatible APIs, and runs explicit split stages
without mesh networking.

Upstream publishes a prebuilt `skippy` CLI for macOS arm64, but only on its
rolling-preview releases — the stable tags do not carry that asset. The formula
therefore pins the newest release that actually ships it, and
`scripts/bump/skippy.py` follows the same rule. `skippy serve` installs a
verified native runtime and downloads models on first use.

```bash
brew install fmu/tap/skippy
skippy doctor
skippy serve --model Qwen3-0.6B-Q4_K_M
```

### mesh-llm

[Mesh-LLM](https://github.com/Mesh-LLM/mesh-llm) pools GPUs and memory across
machines behind one OpenAI-compatible API at `http://localhost:9337/v1`. Its
release bundle is a prebuilt `mesh-llm` host binary plus a verified Metal native
runtime; the formula stages that runtime as an archive and unpacks it after
Homebrew's relocation, because relocation would invalidate the runtime
manifest's per-file hashes.

`mesh-llm` depends on the `skippy` formula: Mesh embeds the same serving
implementation, and the standalone CLI is installed for split-stage and runtime
work.

```bash
brew install fmu/tap/mesh-llm
mesh-llm setup
mesh-llm serve --auto
```

### jadx-headless-mcp

[`jadx-headless-mcp`](https://github.com/1013503897/jadx-headless-mcp) exposes
JADX's `jadx-core` as a stdio MCP server for Android APK analysis, with no GUI.
REA drives it through `REA_JADX_MCP_JAR`, so the formula installs the release
fat JAR at a stable path:

```bash
brew install fmu/tap/jadx-headless-mcp        # latest upstream release
brew install fmu/tap/jadx-headless-mcp@0.7.1  # the release REA verifies
# REA_JADX_MCP_JAR="$(brew --prefix jadx-headless-mcp@0.7.1)/libexec/jadx-headless-mcp.jar"
```

The unversioned formula tracks upstream's latest release and is bumped by
`scripts/bump/jadx-headless-mcp.py`. The JAR REA verifies is a separate,
keg-only versioned formula (`jadx-headless-mcp@0.7.1`) that `scripts/bump/rea.py`
pins and renames together with REA; REA is pointed at that keg explicitly, so
the latest release never shadows the verified JAR.

### kuna

[Kuna](https://github.com/Noelo-Lab/kuna) is an agent-first decompiler
distributed as one self-contained executable. REA drives it through
`REA_KUNA_COMMAND`:

```bash
brew install fmu/tap/kuna        # latest upstream release
brew install fmu/tap/kuna@1.833  # the release REA verifies
# REA_KUNA_COMMAND="$(brew --prefix kuna@1.833)/bin/kuna"
```

The unversioned formula tracks upstream's latest release and is bumped by
`scripts/bump/kuna.py`. The release REA verifies is a separate, keg-only
versioned formula (`kuna@1.833`); only that keg may be on REA's PATH, while
another tap may still ship its own `kuna`. `scripts/bump/rea.py` pins and
renames it together with REA: when REA starts verifying a different Kuna, the
script renames the formula (`Formula/kuna@<old>.rb` → `Formula/kuna@<new>.rb`,
class `KunaAT<old>` → `KunaAT<new>`) and updates the `depends_on` and
documentation that name it, so the pin is never half-migrated.

### ghidra-mcp

[`GhidraMCP`](https://github.com/LaurieWired/GhidraMCP) is a standalone Ghidra
MCP server: a Ghidra extension that serves the open program over loopback HTTP,
plus a Python `ghidra-mcp` MCP server that clients launch. It is independent of
REA, which has its own Ghidra bridge.

```bash
brew install fmu/tap/ghidra-mcp
```

The formula installs the Ghidra extension built for the pinned `ghidra@12.1`
keg, but Homebrew cannot register Ghidra extensions. Register it once, after
Ghidra has been started at least once (it creates
`~/.ghidra/.ghidra_12.1.4_PUBLIC`), using either route:

- Ghidra: File > Install Extensions > "+" > select the extension zip in
  `$(brew --prefix ghidra-mcp)/libexec`, or
- `unzip -d ~/.ghidra/.ghidra_12.1.4_PUBLIC/Extensions <that zip>`

Restart Ghidra, enable `GhidraMCPPlugin` under File > Configure > Developer,
then add the server to your MCP client:

```json
{
  "mcpServers": {
    "ghidra": {
      "command": "/opt/homebrew/opt/ghidra-mcp/bin/ghidra-mcp",
      "args": ["--ghidra-server", "http://127.0.0.1:8080/"]
    }
  }
}
```

A release whose extension was built for a different Ghidra version is not
pinned: `scripts/bump/ghidra-mcp.py` only accepts releases that match the
`ghidra@12.1` keg.

### gbrain

[GBrain](https://github.com/garrytan/gbrain) — Postgres-native personal
knowledge brain with hybrid RAG search. The formula installs upstream's
self-contained binary; it is not the unrelated npm `gbrain` package.

```bash
brew install fmu/tap/gbrain
gbrain init --pglite
gbrain doctor
```

Upstream publishes binaries for macOS arm64 and Linux x86_64 only.

The formula does not wrap or disable gbrain's own updater: `gbrain upgrade`
replaces the binary in the Homebrew keg in place. The scheduled bump keeps the
formula on the latest upstream release, so `brew update && brew upgrade gbrain`
tracks upstream as well. In-place self-update needs a user-writable Homebrew
prefix.

### qwen3-embed

On-demand local Qwen3 embeddings and reranking, served by
[llama.cpp](https://github.com/ggml-org/llama.cpp). It runs one loopback
OpenAI-compatible endpoint that fronts two independent `llama-server`
processes: the embedding model, started on the first embedding request, and
the Qwen3-Reranker-0.6B cross-encoder, started on the first rerank request.
Each one stops again after its own idle window, so either model is resident
only while it is in use and unloading one never disturbs the other.

Nothing in it is specific to [gbrain](https://github.com/garrytan/gbrain): any
client that speaks the OpenAI embeddings API can use the endpoint, and one
intended use is gbrain embedding (where `setup-gbrain` also wires up the reranker).

```bash
brew install fmu/tap/qwen3-embed
```

The formula depends on `bun` and `llama.cpp` from Homebrew; there are no Nix
dependencies, and `serve` needs no gbrain. The optional `setup-gbrain`
integration needs the `gbrain` CLI on `PATH`; install it from this same tap
(`brew install fmu/tap/gbrain`) or use your existing installation.

Post-install, once:

```bash
qwen3-embed setup               # both GGUFs: ~3.3 GB embedding + ~0.6 GB reranker
brew services start qwen3-embed
qwen3-embed setup-gbrain        # optional: configure gbrain (embeddings + reranker) and backfill
```

`model install reranker` installs just the reranker; `model install embedding`
just the embedder. The files live under
`~/.local/share/qwen3-embed/models` by default and, with the integration, are
shared by `gbrain serve`. Both are SHA-256 pinned: the reranker uses the
llama.cpp maintainers' Q8_0 conversion
(`ggml-org/Qwen3-Reranker-0.6B-Q8_0-GGUF`), because the community quantized
conversions drop the classifier tensor that makes the scores meaningful.

`brew services` keeps `qwen3-embed serve` running at login; `qwen3-embed
status`, `qwen3-embed mode throughput`, and `qwen3-embed bench` work against
it (`bench --model reranker` measures the reranker alone). Upgrading
(`brew upgrade qwen3-embed`) replaces the code but not the models or
`~/.config/qwen3-embed/config.json`.

Upgrading from the old `gbrain-embed` name means reinstalling the formula and
moving the state: `brew uninstall gbrain-embed`,
`mv ~/.local/share/gbrain-embed ~/.local/share/qwen3-embed`, same for
`~/.local/state/gbrain-embed` and `~/.config/gbrain-embed`, then
`brew install fmu/tap/qwen3-embed`.

Uninstall:

```bash
brew services stop qwen3-embed
brew uninstall qwen3-embed
```

The formula tracks the tagged source release of
[fmu/qwen3-embed](https://github.com/fmu/qwen3-embed) and is bumped by hand
when that repository is tagged. The current pin is `v0.4.1`: `v0.4.0` split
the gbrain integration out of `setup` into `setup-gbrain`, and `v0.4.1`
corrects the tap name in the project README.

### designcraft-cli

The headless half of [DesignCraft](https://getartcraft.com/apps/designcraft),
the page-layout app that is the `designcraft` cask in homebrew-cask. Upstream
publishes the CLI as a self-contained universal macOS binary next to the app's
own artifacts, so the formula installs that release asset instead of compiling
the engine with Rust: `brew install` and `brew upgrade` download it rather than
spending several minutes in `cargo install`. It runs the app's own layout
composer, renderer and exporter without a window:

```bash
brew install fmu/tap/designcraft-cli
designcraft-cli --version
designcraft-cli commands footnote                       # commands whose id/label/menu match
designcraft-cli run --sample --export page.png          # render a page of the built-in sample
designcraft-cli script page.dcs --export page.pdf       # batch-edit then export
designcraft-cli mcp                                     # MCP server over stdio
```

The CLI and the app are built from one upstream tag: the formula was added at
`0.15.2`, the version the `designcraft` cask is on, and the scheduled bump moves
it to the latest upstream release — the same release homebrew-cask's autobump
puts the app on. The release binary is Developer ID signed and universal
(arm64 and x86_64), and unlike a source build it embeds the optional extra fonts
from [`storytold/craft-fonts`](https://github.com/storytold/craft-fonts), so
non-Latin scripts are set in their intended faces instead of falling back to
system fonts. Upstream ships no Linux CLI binary, so the formula is macOS-only.

### figcraft-cli

The headless half of [FigCraft](https://getartcraft.com/apps/figcraft), the
interface design and prototyping tool that is the `figcraft` cask in
homebrew-cask. Upstream publishes the CLI as a self-contained universal macOS
binary next to the app's own artifacts, so the formula installs that release
asset instead of compiling the engine with Rust: `brew install` and
`brew upgrade` download it rather than spending several minutes in
`cargo install`. It runs the app's own document model, renderer and exporters
without a window:

```bash
brew install fmu/tap/figcraft-cli
figcraft-cli --version
figcraft-cli commands                                 # every command with its parameters
figcraft-cli info artwork.figcraft                    # pages, node and style counts
figcraft-cli render artwork.figcraft -o page.png --scale 2
figcraft-cli convert artwork.figcraft artwork.pdf     # .figcraft, .json, .svg, .png, .pdf, .fig, .penpot
figcraft-cli run build-card.json --out card.figcraft  # a command script, headless
figcraft-cli mcp                                      # MCP server over stdio
```

The CLI and the app are built from one upstream tag: the formula was added at
`0.14.0`, the version the `figcraft` cask is on, and the scheduled bump moves
it to the latest upstream release — the same release homebrew-cask's autobump
puts the app on. The release binary is Developer ID signed, notarized and
universal (arm64 and x86_64), and unlike a source build it embeds the optional
extra fonts from
[`storytold/craft-fonts`](https://github.com/storytold/craft-fonts), so
non-Latin text is set in its intended faces instead of falling back to system
fonts. Upstream ships no Linux CLI binary, so the formula is macOS-only.

### solidcraft-cli

The headless half of [SolidCraft](https://solidcraft.io/), the parametric 3D CAD
modeller that is the `solidcraft` cask in homebrew-cask. Upstream publishes the
CLI as a self-contained universal macOS binary next to the app's own artifacts,
so the formula installs that release asset instead of compiling the kernel with
Rust: `brew install` and `brew upgrade` download it rather than spending several
minutes in `cargo install`. It runs the app's own solid kernel, evaluator and
exporters without a window:

```bash
brew install fmu/tap/solidcraft-cli
solidcraft-cli --version
solidcraft-cli commands                              # the command registry, as JSON
solidcraft-cli run box.json --out box.step           # a command script, exported to STEP
solidcraft-cli eval --in box.step                    # bodies, mass and volume as JSON
solidcraft-cli snapshot box.json --out box.png       # a headless render
solidcraft-cli mcp                                   # MCP server over stdio
```

The CLI and the app are built from one upstream tag and the scheduled bump
follows the latest upstream release — the same release stream homebrew-cask's
`solidcraft` cask tracks. The release binary is Developer ID signed, notarized
and universal (arm64 and x86_64). Upstream ships no Linux CLI binary, so the
formula is macOS-only; the archive's deprecated `solvecraft-cli` alias is not
installed.

### vectorcraft-cli

The headless half of [VectorCraft](https://getartcraft.com/apps/vectorcraft),
the vector editor that is the `vectorcraft` cask in homebrew-cask. Upstream
publishes the CLI as a self-contained universal macOS binary next to the app's
own artifacts, so the formula installs that release asset instead of compiling
the engine with Rust: `brew install` and `brew upgrade` download it rather than
spending several minutes in `cargo install`. It runs the app's own document,
rendering and export engine without a window:

```bash
brew install fmu/tap/vectorcraft-cli
vectorcraft-cli --version
vectorcraft-cli commands shape.rectangle               # the command catalogue, as JSON
vectorcraft-cli info artwork.svg                       # document summary as JSON
vectorcraft-cli convert artwork.svg artwork.pdf        # re-export in another format
vectorcraft-cli run --cmd file.new --cmd shape.rectangle --export page.svg
vectorcraft-cli mcp                                    # MCP server over stdio
```

The CLI and the app are built from one upstream tag: the formula was added at
`0.20.0`, the version the `vectorcraft` cask is on, and the scheduled bump moves
it to the latest upstream release — the same release homebrew-cask's autobump
puts the app on. The release binary is Developer ID signed, notarized and
universal (arm64 and x86_64), and unlike a source build it embeds the optional
extra fonts from
[`storytold/craft-fonts`](https://github.com/storytold/craft-fonts), so
non-Latin text is set in its intended faces instead of falling back to system
fonts. Upstream ships no Linux CLI binary, so the formula is macOS-only.

### wordcraft-cli

The headless half of [WordCraft](https://getartcraft.com/apps/wordcraft), the
word processor that is the `wordcraft` cask in homebrew-cask. Upstream publishes
the CLI as a self-contained universal macOS binary next to the app's own
artifacts, so the formula installs that release asset instead of compiling the
engine with Rust: `brew install` and `brew upgrade` download it rather than
spending several minutes in `cargo install`. It runs the app's own document
model, saver and exporters without a window:

```bash
brew install fmu/tap/wordcraft-cli
wordcraft-cli --version
wordcraft-cli commands                                 # the command catalogue
wordcraft-cli convert report.docx report.pdf           # docx, pdf, odt, rtf, html, md, tex, txt, png
wordcraft-cli text report.docx                         # plain text
wordcraft-cli inspect report.docx                      # structure as JSON
wordcraft-cli run --template sample --cmd 'text.insert={"text":"Hello"}' --save out.docx
wordcraft-cli mcp                                      # MCP server over stdio
```

The CLI and the app are built from one upstream tag: the formula was added at
`0.14.0`, the version the `wordcraft` cask is on, and the scheduled bump moves
it to the latest upstream release — the same release homebrew-cask's autobump
puts the app on. The release binary is Developer ID signed, notarized and
universal (arm64 and x86_64), and unlike a source build it embeds the optional
extra fonts from
[`storytold/craft-fonts`](https://github.com/storytold/craft-fonts), so
non-Latin text is set in its intended faces instead of falling back to system
fonts. Upstream ships no Linux CLI binary, so the formula is macOS-only.

### pared

The CLI half of [Pared](https://github.com/4evy/pared); the app is the
`pared-app` cask below. Upstream's own formula builds from source and requires
Xcode 27, so this tap pins the released tarball instead. Both artifacts come
from the same tag and are re-pinned together.

```bash
brew install fmu/tap/pared
```

The release is Apple silicon and macOS 27 only, and the formula declares that
floor, so installing it on an older host fails instead of producing a binary
that cannot start.

### ghidra@12.1

Ghidra 12.1.4, pinned. Homebrew core has moved on to 12.2; this keg stays on
12.1.4 because both consumers need that exact release: REA verifies its Ghidra
bridge against 12.1.4, and GhidraMCP publishes one extension per Ghidra release.
A mismatch is not rejected by Ghidra's extension loader at startup — an API move
only shows up later as a `NoClassDefFoundError` inside the affected tool.

```bash
brew install fmu/tap/ghidra@12.1
```

It is keg-only, so it coexists with core's `ghidra` without either formula
owning `/opt/homebrew/bin/ghidraRun`. The public release archive ships native
components for Windows and Linux only, so the formula also compiles the macOS
native components (the decompiler, Sleigh and the demangler) with the archive's
documented `support/gradle/gradlew buildNatives` run. That needs the formula's
JDK 21 and network access for the Gradle wrapper's first download. `rea` and
`ghidra-mcp` depend on this keg, so installing either builds it.

The scheduled bump does not touch this formula: the pin is the point. It moves
when REA verifies a new Ghidra release (and GhidraMCP ships an extension for
it), which is a hand change; `scripts/bump/rea.py` fails rather than publishing
a tap whose REA and Ghidra pins disagree.

## Casks

None of these casks is in homebrew-cask. `baocut` and `iqualize` simply have no
homebrew-cask entry; the other three fail homebrew-cask's notarization
requirement, and their casks carry the one-time Gatekeeper workaround as a
caveat.

### baocut

[BaoCut](https://baocut.com/) is an AI video agent with an editable timeline: it
transcribes, subtitles, translates, dubs, cuts and animates, and every result
lands in a timeline you can keep editing. It is Apple silicon and macOS 14+ only,
and upstream signs and notarizes the app, so unlike the other casks here it needs
no Gatekeeper workaround. It has no homebrew-cask entry yet, which is why it
lives in this tap.

```bash
brew install --cask fmu/tap/baocut
open -a BaoCut
baocut-cli version        # the app's agent entrypoint, linked into the prefix
baocut-cli status         # what this machine can do: runtime, tools and models
```

The app updates itself from the release's appcast feed, so `brew upgrade` defers
to it; the scheduled bump keeps the tap's pin current for fresh installs.
`baocut-cli` is the CLI the desktop bundle already ships — the same release as
the app — linked into the Homebrew prefix so it works from a shell;
`BAOCUT_CLI` can point at `$(brew --prefix)/bin/baocut-cli` when a tool needs an
absolute path. The cask depends on the `ffmpeg` formula, which supplies the
`ffmpeg` and `ffprobe` the app's media analysis, transcription preparation and
export shell out to.

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
leaves alone. The cask also seeds the community extension registry
([`mornyeapp/Mornye-Extension`](https://github.com/mornyeapp/Mornye-Extension))
into the app's preferences on install and upgrade, so Settings > Extensions >
Repo lists it without the URL being typed in by hand.

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
purpose: `fmu/tap/pared` is the CLI's Homebrew route, and a second
Homebrew-owned `pared` would shadow it.

## Upstream bumps

[`bump-upstream.yml`](.github/workflows/bump-upstream.yml) re-pins the tap's
packages every 30 minutes. For each package, [`scripts/bump/`](scripts/bump/)
resolves upstream's latest release tag, downloads the release asset(s), computes
their SHA-256, rewrites the version and checksums, and — when something moved —
commits, pushes and dispatches the macOS CI run. The commit body lists only the
packages that moved; a package that was already current is reported in the job
log but left out of the commit message. The same holds for the engine pin matrix
[`scripts/bump/rea.py`](scripts/bump/rea.py) verifies: its `matches REA` lines
reach the commit body only when a bump moved `rea` itself, and a bump that only
touched an unrelated package keeps them in the job log.

| package | upstream | release tag |
| --- | --- | --- |
| `rea` (+ `rea-full`, `jadx-headless-mcp@<REA pin>`, `kuna@<REA pin>`) | `morluto/rea` | `rea-agents-<version>` |
| `jadx-headless-mcp` (latest; REA uses `jadx-headless-mcp@<REA pin>`) | `1013503897/jadx-headless-mcp` | `v*` |
| `kuna` (latest; REA uses `kuna@<REA pin>`) | `Noelo-Lab/kuna` | `v*` |
| `unblob` | `onekey-sec/unblob` | PyPI `unblob` release (wheels) |
| `sasquatch` | `onekey-sec/sasquatch` | `sasquatch-v*` |
| `partclone` | `Thomas-Tsai/partclone` | `<version>` |
| `skippy` | `Mesh-LLM/mesh-llm` | rolling preview with a `skippy` CLI asset |
| `mesh-llm` | `Mesh-LLM/mesh-llm` | `v*` |
| `ghidra-mcp` | `LaurieWired/GhidraMCP` | `<version>` |
| `gbrain` | `garrytan/gbrain` | `v*` |
| `designcraft-cli` | `storytold/designcraft` | `v*` (the tag the `designcraft` cask is on) |
| `figcraft-cli` | `storytold/figcraft` | `v*` (the tag the `figcraft` cask is on) |
| `solidcraft-cli` | `tangency-labs/solidcraft` | `v*` (the release stream the `solidcraft` cask tracks) |
| `vectorcraft-cli` | `storytold/vectorcraft` | `v*` (the tag the `vectorcraft` cask is on) |
| `wordcraft-cli` | `storytold/wordcraft` | `v*` (the tag the `wordcraft` cask is on) |
| `baocut` | `JimLiu/baocut` | `baocut-v*` |
| `iqualize` | `dariuscorvus/iqualize` | `v*` |
| `mornye` | `mornyeapp/Mornye-Desktop` | `v*` |
| `mpv-app` | `mpv-player/mpv` | `v*` (stable) |
| `pared` + `pared-app` | `4evy/pared` | no `v` prefix |

Two things are coupled rather than independent:

- `rea` is the authority for the pinned engine versions. `scripts/bump/rea.py`
  pins the `rea-agents` npm tarball and reads the engine releases the new tag
  verifies from its source (`src/android/JadxRelease.ts`,
  `src/kuna/KunaRelease.ts`, `src/ghidra/GhidraReleasePolicy.ts`), then re-pins
  `Formula/rea.rb`, `Formula/rea-full.rb` and the versioned kegs
  `Formula/jadx-headless-mcp@<release>.rb` and `Formula/kuna@<release>.rb` in one
  commit. When REA verifies a different JADX or Kuna, the script renames that
  keg and every `depends_on`/doc reference with it. A Ghidra move also needs a
  new `ghidra@12.1` keg and a GhidraMCP extension built for that release, so the
  script fails instead of writing a tap whose pins disagree. The unversioned
  `jadx-headless-mcp` and `kuna` formulae are not part of that pin: they track
  upstream's latest releases and are bumped by their own scripts.
- `ghidra-mcp` only accepts a release whose extension targets the Ghidra keg the
  tap pins; it never creates a mismatched extension.

`ghidra@12.1` is deliberately absent from the table (see above), and
`qwen3-embed` follows a hand-made tag of `fmu/qwen3-embed` rather than a
GitHub release.

CI also runs `python3 scripts/bump/rea.py --check`, which compares the tap's
engine pins with the releases the pinned REA version verifies and exits non-zero
on drift without touching the npm registry.

A manual run can pin a specific tag for one package:

```bash
gh workflow run bump-upstream.yml -f package=mornye -f tag=v5.2.6
gh workflow run bump-upstream.yml -f package=rea -f tag=rea-agents-6.8.0
```

Bump scripts can also be run locally; they need only `python3` and, for the
GitHub API, an optional `GH_TOKEN`:

```bash
python3 scripts/bump/mornye.py            # latest upstream release
RELEASE_TAG=v5.2.6 python3 scripts/bump/mornye.py   # a specific tag
python3 scripts/bump/kuna.py              # latest Kuna, for the unversioned formula
python3 scripts/bump/rea.py --check       # verify the engine pin matrix
```

## Development

Formulae are under `Formula/` and casks under `Casks/`; both are plain Ruby
files. [`ci.yml`](.github/workflows/ci.yml) audits every formula and cask on the
latest macOS, installs the packages the runner can run, runs the formula tests,
and checks that the engine pins match the pinned REA release. The two Apple
silicon/macOS 27 artifacts are only installed when the runner is new enough; the
reverse-engineering toolchain is installed on every run, which builds
`ghidra@12.1`'s macOS native components and therefore dominates the job time.

`audit_exceptions/mismatched_binary_allowlist.json` records the one x86_64
Mach-O helper that Ghidra's own archive carries. It only matters when the keg is
installed locally: audit inspects the installed cellar, and the CI runner audits
before installing.

To validate a change locally before pushing, tap the checkout under a throwaway
name (Homebrew refuses a second tap named `fmu/tap` while the real one is
installed):

```bash
brew tap fmu/audit "file://$PWD"   # the tap is named fmu/audit
brew trust fmu/audit
brew audit --strict fmu/audit/gbrain fmu/audit/qwen3-embed \
  fmu/audit/pared fmu/audit/ghidra@12.1 \
  fmu/audit/jadx-headless-mcp fmu/audit/jadx-headless-mcp@0.7.1 \
  fmu/audit/kuna fmu/audit/kuna@1.833 \
  fmu/audit/ghidra-mcp fmu/audit/rea \
  fmu/audit/skippy fmu/audit/mesh-llm
brew audit --strict --cask fmu/audit/iqualize fmu/audit/mornye \
  fmu/audit/mpv-app fmu/audit/pared-app
brew untap fmu/audit
```
