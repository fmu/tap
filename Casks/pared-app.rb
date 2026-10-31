# Pared is the app for choosing which Apple Intelligence features stay on a Mac
# and for removing the downloaded model assets of the ones that do not. The same
# release also ships a CLI; that is Formula/pared.rb, not this cask.
#
# It lives in this tap because the release is ad-hoc signed: no Developer ID, no
# hardened runtime, no notarization ticket, and `spctl -a -t install` rejects the
# bundle. homebrew-cask requires a notarized app, so upstream's own release cannot
# go there. The app is also Apple silicon only and every 1.x/2.x asset is built
# against the macOS 27 SDK (LSMinimumSystemVersion 27.0), which both `depends_on`
# stanzas state as a real floor rather than as documentation.
#
# Sparkle is inside the bundle: SUFeedURL points at the release's appcast.xml, so
# the app updates itself and `brew upgrade` defers to it.
#
# The bundle carries a copy of the CLI at Contents/Helpers/pared, but this cask
# deliberately has no `binary` stanza. The CLI's Homebrew route is
# Formula/pared.rb, and a second Homebrew-owned `pared` in /opt/homebrew/bin would
# shadow it and drift apart on upgrade.
cask "pared-app" do
  version "2.2.0"
  sha256 "8966f3e34f7ab1381a7264210b6288aa6c40cbab9f1c9633e3c2a206eb16d9fe"

  url "https://github.com/4evy/pared/releases/download/#{version}/pared-app-macos-arm64.zip"
  name "Pared"
  desc "Control Apple Intelligence features and remove downloaded models"
  homepage "https://github.com/4evy/pared"

  livecheck do
    url :url
    strategy :github_latest
  end

  auto_updates true
  depends_on arch: :arm64
  depends_on macos: :golden_gate

  app "Pared.app"

  # There is no pkg, launchd job or login item: the configuration profile the app
  # offers to install is installed by the user through System Settings, and no
  # file outside the bundle belongs to this cask. Only the app is quit here.
  uninstall quit: "org.pared.app"

  # State is keyed by org.pared.app. The policy, the generated profile and the
  # declarations live in the shared Application Support/pared directory that the
  # CLI also reads, so a --zap uninstall also drops the formula's policy file;
  # the profile itself stays in System Settings and is not a file zap could own.
  # Sparkle keeps its downloads under Caches; preferences written through
  # CFPreferences land in the defaults plist.
  zap trash: [
    "~/Library/Application Support/pared",
    "~/Library/Caches/org.pared.app",
    "~/Library/Preferences/org.pared.app.plist",
    "~/Library/Saved Application State/org.pared.app.savedState",
  ]

  # scripts/release/release.sh signs the app with `codesign --force --sign -`, so
  # Homebrew 7 quarantines the download (cask/quarantine.rb) and Gatekeeper blocks
  # the first launch. The app cannot fix its signature from this side.
  caveats <<~EOS
    Pared is not notarized: it is ad-hoc signed, so macOS cannot confirm who
    built it. Homebrew quarantines the app on install, so Gatekeeper blocks the
    first launch; approve it once in System Settings > Privacy & Security >
    Open Anyway, or clear the attribute yourself:

      xattr -dr com.apple.quarantine /Applications/Pared.app

    The configuration profile Pared generates is installed by hand in System
    Settings. Uninstalling the app does not remove it; remove it in
    System Settings > General > Device Management.
  EOS
end
