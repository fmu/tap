cask "mornye" do
  version "5.3.1"
  sha256 "c1729bfb7a468b9985254979ee178c6412567d48859cc0cefd1f22a4d6e0a54e"

  url "https://github.com/mornyeapp/Mornye-Desktop/releases/download/v#{version}/Mornye-v#{version}-macos-universal.dmg"
  name "Mornye"
  desc "Music library player with synced lyrics and tag editing"
  homepage "https://desktop.mornye.com/"

  livecheck do
    url :url
    strategy :github_latest
  end

  # Mornye ships its own updater: Dart `DesktopUpdater` polls
  # https://api.github.com/repos/mornyeapp/Mornye-Desktop, offers "Check for
  # Updates" in the app, downloads the released DMG and asks for a restart.
  # There is no Sparkle or Tauri updater in the bundle. Declaring this is what
  # tells Homebrew how to treat the app; without it `brew upgrade` would race
  # the in-app updater for the same bundle.
  auto_updates true
  # LSMinimumSystemVersion is 12.0, and the bundled FFmpeg is built with
  # -mmacosx-version-min=12.0. Homebrew 7's floor is macOS 11, so this stanza
  # matters on Big Sur. The bare symbol is the non-deprecated spelling: Homebrew
  # 7 warns on the old `">= :monterey"` comparison string.
  depends_on macos: :monterey

  app "Mornye.app"

  # Mornye ships no extension-store URL, so a fresh install would otherwise need
  # the registry typed by hand on Settings > Extensions > Repo. Seed the
  # community registry (a `registry.json` index of `.sflx` packages) instead, on
  # install and on every upgrade.
  #
  # `postflight_steps` runs sandboxed with HOME pointing at a temporary
  # directory, and its declarative DSL interpolates its own tokens, not
  # `Dir.home`. `{{user}}` expands to the account name, so the preferences path
  # is spelled from it and the cask allows writes only to that directory.
  # Writing the domain by path also avoids the cfprefsd lookup the sandbox
  # denies; the value is readable as `defaults read com.zarz.mornye
  # flutter.store_registry_url` afterwards.
  postflight_steps do
    run "/usr/bin/defaults",
        args:           ["write", "/Users/{{user}}/Library/Preferences/com.zarz.mornye",
                         "flutter.store_registry_url", "-string",
                         "https://raw.githubusercontent.com/mornyeapp/Mornye-Extension/main/registry.json"],
        writable_paths: ["/Users/{{user}}/Library/Preferences"]
  end

  # The DMG holds only Mornye.app and an /Applications symlink; there is no pkg,
  # helper, daemon or login item, so no `uninstall pkgutil:`/`launchctl` stanza.

  # The app is not sandboxed, so its state lives in the ordinary per-user
  # Library paths, keyed by the com.zarz.mornye bundle id. `library.db`,
  # `history.db`, `covers/` and `rust-panic.log` are the files the Rust core
  # writes; the concrete base directory is computed at runtime by path_provider,
  # so the name follows the bundle id rather than appearing as a literal in the
  # binary. Downloaded music goes to ~/Downloads/Mornye and is user data, not
  # app state, so `zap` must never touch it. Keychain items (flutter_secure_
  # storage) have no declarative zap.
  zap trash: [
    "~/Library/Application Support/com.zarz.mornye",
    "~/Library/Caches/com.zarz.mornye",
    "~/Library/Preferences/com.zarz.mornye.plist",
    "~/Library/Saved Application State/com.zarz.mornye.savedState",
  ]

  # The release is ad-hoc signed: no Developer ID, no hardened runtime, no
  # stapled ticket, and `spctl -a -t install` rejects it. The official
  # homebrew-cask tap requires notarization, which is why the release is tracked
  # in this tap instead of homebrew-cask. Homebrew 7 dropped the automatic
  # caveat for unnotarized apps (cask/artifact/app.rb has no caveat method) and
  # now quarantines cask downloads itself: cask/quarantine.rb writes a "Homebrew
  # Cask" com.apple.quarantine attribute, so the installed bundle is checked by
  # Gatekeeper and the first launch is blocked. Say so, since the app cannot fix
  # its signature from this side.
  caveats <<~EOS
    Mornye is not notarized: it is ad-hoc signed, so macOS cannot confirm who
    built it. Homebrew quarantines the app on install, so Gatekeeper blocks the
    first launch; approve it once in System Settings > Privacy & Security >
    Open Anyway, or clear the attribute yourself:

      xattr -dr com.apple.quarantine /Applications/Mornye.app
  EOS
end
