# AGENTS.md

Notes for agents and contributors working in this tap.

## Repairing a formula requires a `revision` bump

When a commit changes what a formula *installs* — installed files, generated
launchers or wrappers, baked-in paths, or caveats/test that assume the new keg —
but the upstream `version` does not change, add or increment `revision` in the
same commit:

```ruby
class ReaFull < Formula
  # ...
  revision 1
end
```

Homebrew tracks an installed keg by `version` + `revision`, not by file
contents. Without the bump, `brew upgrade` treats every existing install as
current and only fresh installs receive the repair; affected users keep the old
keg until they happen to run `brew reinstall` themselves.

- First repair of a release: `revision 1`. Each further repair of the same
  release: increment it.
- Remove the `revision` line (back to 0) when the next upstream version bump
  lands; for `rea`/`rea-full`, `scripts/bump/rea.py` drops it automatically.
- Version-only bumps from `scripts/bump/` need no revision; they already change
  `version`.

## Bottled formulae must not keep a stale `bottle do` block

`libntfs-3g`, `ntfsprogs`, `partclone`, `sasquatch`, `ghidra@12.1`,
`ghidra-mcp`, `unblob` and `serena` are published as bottles by
[`bottles.yml`](.github/workflows/bottles.yml); that workflow owns their
`bottle do` blocks and regenerates them from the assets it uploads. A block left
behind when `version` or `revision` moves pins a checksum for a bottle URL that
carries the new package version, which does not exist until the workflow has
rebuilt it: `brew install` would fail with a 404 instead of building from source.

- Version bumps through `scripts/bump/` drop the block automatically.
- A hand-made repair that bumps `revision` must drop the block by hand.
- Do not write a block by hand; dispatch `bottles.yml` to publish new bottles.
- `Formula/ghidra@12.1.rb` is pinned by hand, so drop its block by hand when the
  pin moves. A change there also rebuilds `ghidra-mcp`'s bottle, which targets
  that keg.
