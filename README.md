# fmu/homebrew

Homebrew formulae for [fmu](https://github.com/fmu)'s tools.

```bash
# This tap is a multi-formula repository named `homebrew`, so Homebrew cannot
# derive its URL from `user/repo`; pass the URL explicitly (one time).
brew tap fmu/homebrew https://github.com/fmu/homebrew.git
```

Then install a formula by name:

```bash
brew install gbrain-embed
```

## Formulae

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
dependencies. `gbrain` itself is not distributed here — install it separately
and keep it on `PATH`.

Post-install, once:

```bash
gbrain-embed model install      # 3.3 GB GGUF, SHA-256 verified
gbrain-embed setup              # configure gbrain and backfill
brew services start gbrain-embed
```

`brew services` keeps `gbrain-embed serve` running at login; `gbrain-embed status`,
`gbrain-embed mode throughput`, and `gbrain-embed bench` work against it. Upgrading (`brew upgrade gbrain-embed`) replaces the code but not the model
or `~/.config/gbrain-embed/config.json`.

Uninstall:

```bash
brew services stop gbrain-embed
brew uninstall gbrain-embed
```

## Development

Formulae are plain Ruby files under `Formula/`. CI audits and installs each
formula on the latest macOS.
