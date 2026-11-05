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
