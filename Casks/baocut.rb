# BaoCut is an AI video agent with an editable timeline: it transcribes,
# subtitles, translates, dubs, cuts and animates, and every result lands in a
# timeline you can keep editing. The app is Electron 44.9.3 and upstream ships
# it for Apple silicon and macOS 14+ only, Developer ID signed and notarized, so
# this cask needs no Gatekeeper caveat.
#
# It has no homebrew-cask entry yet, which is why it lives here. The cask points
# at upstream's release DMG; nothing is re-hosted.
#
# The app updates itself from the release's appcast JSON
# (`appcast-aarch64-apple-darwin.json`, overridable with `BAOCUT_UPDATE_APPCAST`),
# so `auto_updates true` keeps `brew upgrade` from racing the in-app updater.
#
# The bundle also carries the agent entrypoint at Contents/MacOS/baocut-cli.
# Upstream documents that launcher as safe to expose through a symlink (it
# resolves the app bundle from its own path), so `binary` links it into the
# Homebrew prefix and `baocut-cli` works from a shell. It is the same release as
# the app, not a separate package.
#
# The DMG holds only BaoCut.app and an /Applications symlink: no pkg, daemon,
# login item or privileged helper.
cask "baocut" do
  version "3.19.0-build.95"
  sha256 "ad2b8a291867dd34b3cad88a856206bcac6a6fd11ff98e92f583763c52602c71"

  url "https://github.com/jimliu/baocut/releases/download/baocut-v#{version}/BaoCut-#{version}-aarch64-apple-darwin.dmg"
  name "BaoCut"
  desc "AI video agent with an editable timeline"
  homepage "https://baocut.com/"

  livecheck do
    url :url
    strategy :github_latest
    regex(/^baocut-v?(\d+(?:\.\d+)+-build\.\d+)$/i)
  end

  auto_updates true
  depends_on arch: :arm64
  # Media analysis, transcription preparation and export shell out to ffmpeg and
  # ffprobe; the app discovers them on PATH and does not bundle them.
  depends_on formula: "ffmpeg"
  # LSMinimumSystemVersion is 14.0; the bare symbol is the non-deprecated
  # spelling Homebrew 7 wants.
  depends_on macos: :sonoma

  app "BaoCut.app"
  binary "#{appdir}/BaoCut.app/Contents/MacOS/baocut-cli"

  uninstall quit: "com.baocut.app"

  # Electron state is keyed by the app name and the bundle id. The CLI's
  # BAOCUT_HOME defaults to ~/.baocut when no app runtime is running, while the
  # desktop app keeps its runtime home under Application Support/BaoCut; both
  # hold sessions, logs and downloaded models. `skill install` also leaves
  # symlinks into the bundle under ~/.agents and ~/.claude.
  #
  # Projects are user data: "New project" creates them in ~/BaoCut by default,
  # so zap must never touch that directory.
  zap trash: [
    "~/.agents/skills/baocut",
    "~/.baocut",
    "~/.claude/skills/baocut",
    "~/Library/Application Support/BaoCut",
    "~/Library/Caches/BaoCut",
    "~/Library/Caches/com.baocut.app",
    "~/Library/Logs/BaoCut",
    "~/Library/Preferences/com.baocut.app.plist",
    "~/Library/Saved Application State/com.baocut.app.savedState",
  ]

  caveats <<~EOS
    `baocut-cli` is the app's agent entrypoint, linked from
    Contents/MacOS/baocut-cli. Tools that need an absolute path can use
    BAOCUT_CLI="#{HOMEBREW_PREFIX}/bin/baocut-cli".
  EOS
end
