# fmu/homebrew

Homebrew formulae for [fmu](https://github.com/fmu)'s tools.

```bash
# This tap is a multi-formula repository named `homebrew`, so Homebrew cannot
# derive its URL from `user/repo`; pass the URL explicitly (one time).
brew tap fmu/homebrew https://github.com/fmu/homebrew.git

# Homebrew 5+ keeps third-party taps untrusted until they are named.
brew trust fmu/homebrew
```

Then install the formulae you want:

```bash
brew install gbrain          # the GBrain CLI
brew install gbrain-embed    # on-demand local embeddings for gbrain
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
replaces the binary in the Homebrew keg in place. A scheduled workflow
([`bump-gbrain.yml`](.github/workflows/bump-gbrain.yml)) re-pins the formula to
the latest upstream release every 30 minutes, so `brew update && brew upgrade
gbrain` tracks upstream as well. In-place self-update needs a user-writable
Homebrew prefix.

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

## Development

Formulae are plain Ruby files under `Formula/`. CI audits, installs and tests
each formula on the latest macOS. [`bump-gbrain.yml`](.github/workflows/bump-gbrain.yml)
re-pins `gbrain` to the latest upstream release every 30 minutes and then
re-runs CI for the pushed formula.
