# Multica Desktop is the native client for Multica, an agent workspace where
# issues are assigned to AI coding agents the way they are to teammates. The app
# is Electron 44, Developer ID signed and notarized by upstream, and ships one
# DMG per CPU architecture (Apple silicon and Intel), so the cask selects the
# matching one per host.
#
# It has no homebrew-cask entry yet, which is why it lives here. The cask points
# at upstream's release DMGs; nothing is re-hosted.
#
# The app updates itself with electron-updater (`auto_updates true`): it checks
# hourly, downloads in the background and installs on quit, with an extra update
# feed for Intel Macs. `brew upgrade` therefore defers to the in-app updater;
# the scheduled bump keeps the tap's pin current for fresh installs.
#
# The bundle ships the `multica` CLI from the same release (the app runs that
# copy for its managed daemon, at
# Contents/Resources/app.asar.unpacked/resources/bin/multica). The cask links it
# into the Homebrew prefix as `multica`, so the CLI works in a terminal without a
# second install and follows the app through its own updates. Upstream also
# publishes the CLI as a standalone package in a separate tap
# (multica-ai/homebrew-tap); that formula owns the same `multica` command, so the
# two are alternatives and the caveat points at it.
#
# The volume holds Multica.app and an /Applications symlink: no pkg, launchd
# job, login item or privileged helper. The daemon the app manages is a child
# process of the bundled CLI, not a service.
cask "multica-desktop" do
  version "0.8.1"

  on_arm do
    sha256 "186d2d1c4d9bbbae17b7a5c72946b5f12f48a8a86fe28948128131f56e3f7d3c"

    url "https://github.com/multica-ai/multica/releases/download/v#{version}/multica-desktop-#{version}-mac-arm64.dmg"
  end
  on_intel do
    sha256 "e8f410f6494f08db3e163ffaa2b358b11381ed2372dbe6b6e0998fa6dbad3da8"

    url "https://github.com/multica-ai/multica/releases/download/v#{version}/multica-desktop-#{version}-mac-x64.dmg"
  end

  name "Multica"
  desc "Desktop client for the Multica agent workspace"
  homepage "https://multica.ai/"

  livecheck do
    url "https://github.com/multica-ai/multica"
    strategy :github_latest
  end

  # Electron 44 requires macOS 13 Ventura; every mac bundle declares
  # LSMinimumSystemVersion 13.0.
  auto_updates true
  depends_on macos: :ventura

  app "Multica.app"
  # The CLI copy the app itself runs. It sits in `app.asar.unpacked` (because of
  # `asarUnpack: resources/**`), so it is a real executable on disk and can be
  # linked as-is. The link points into the bundle, so it tracks updates to the
  # app instead of freezing one release's CLI in the prefix.
  binary "#{appdir}/Multica.app/Contents/Resources/app.asar.unpacked/resources/bin/multica"

  uninstall quit: "ai.multica.desktop"

  # The app's state is keyed by the ai.multica.desktop bundle id, except for the
  # profile data it deliberately keeps outside it. `~/.multica` also holds the
  # standalone CLI's default profile ("config.json" and its daemon files), which
  # this cask must not touch: zapping the whole directory would delete CLI state
  # that belongs to the multica-ai/tap/multica formula. Only Desktop's own files
  # there are listed: the self-hosted target (desktop.json), the daemon
  # preferences (desktop_prefs.json) and the per-service daemon profile
  # (profiles/desktop-<host>/, holding config, log, pid and port). Application
  # Support holds the Electron profile (window state, saved tabs as
  # localStorage, updater preferences and, only when the bundled CLI is missing,
  # the CLI copy the app downloads on first launch). The updater's downloaded
  # packages go to the cache directory named in the app's app-update.yml
  # (`updaterCacheDirName: @multicadesktop-updater`).
  zap trash: [
    "~/.multica/desktop.json",
    "~/.multica/desktop_prefs.json",
    "~/.multica/profiles/desktop-*",
    "~/Library/Application Support/Multica",
    "~/Library/Caches/@multicadesktop-updater",
    "~/Library/HTTPStorages/ai.multica.desktop",
    "~/Library/Preferences/ai.multica.desktop.plist",
    "~/Library/Saved Application State/ai.multica.desktop.savedState",
  ]

  # The linked CLI is the app's own copy. Upstream also publishes the CLI as a
  # CLI-only package in its own tap, which is the route for a machine that does
  # not want the desktop app; both own `bin/multica`, so say that they are
  # alternatives rather than leaving a silent symlink conflict to be discovered.
  caveats <<~EOS
    The bundled Multica CLI is linked into your PATH as `multica`, and it
    updates together with the app.

    For the CLI alone, without the desktop app, install the standalone package
    from upstream's tap instead:

      brew install multica-ai/tap/multica

    https://github.com/multica-ai/homebrew-tap

    That formula and this cask both own `multica`, so install one or the other:
    Homebrew warns and keeps the existing link instead of overwriting it.
  EOS
end
