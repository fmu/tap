# The first-party mpv app bundle: the macOS build mpv's own GitHub Actions CI
# publishes, linked from https://mpv.io/installation/ under "First-party
# builds". It needs a cask in this tap because mpv has no notarized macOS
# distribution: the `mpv` formula is explicitly CLI-only ("without application
# bundles" on that page), and the third-party stolendata build was disabled in
# homebrew-cask on 2026-09-01 for failing the Gatekeeper check. This bundle is
# ad-hoc signed too, so the caveat below is the price of using it.
#
# It tracks the latest *stable* release rather than the rolling `git-release`
# tag that mpv.io's macOS row links to. That tag is rebuilt on every push to
# master: the asset filenames embed the commit, the assets are replaced on each
# run, and there is no release-independent URL for the newest one, so a cask
# pinning it would 404 within a day. Stable assets are immutable, which is what
# a pinned sha256 needs. The scheduled bump re-pins `version` and the four hashes
# from the release assets; `livecheck` reports the next stable tag.
#
# mpv publishes one asset per macOS version its CI runs on, and each asset
# carries a matching LC_BUILD_VERSION `minos` (the macOS 15 build is `minos
# 15.0`, the macOS 26 build `minos 26.0`), so the URL follows both the
# architecture and the running macOS version. The release zip also only holds a
# `mpv.tar.gz`, hence `container nested:`.
cask "mpv-app" do
  version "0.41.0"

  on_arm do
    on_sonoma :or_older do
      sha256 "5c96f9b21355fc0a11d2e2161ad65f33031070e9fb3f6bd9865fb459b94587e6"
      url "https://github.com/mpv-player/mpv/releases/download/v#{version}/mpv-v#{version}-macos-14-arm.zip"
    end

    on_sequoia do
      sha256 "489cf6a54f57c54f86ad8d7cedaf5bb26848770d58dc059021214e2f689ee799"
      url "https://github.com/mpv-player/mpv/releases/download/v#{version}/mpv-v#{version}-macos-15-arm.zip"
    end

    on_tahoe :or_newer do
      sha256 "09820c0d84f6687446b84eb9df81fcf6a26ebe869cee58ea1857d7948cfb7c71"
      url "https://github.com/mpv-player/mpv/releases/download/v#{version}/mpv-v#{version}-macos-26-arm.zip"
    end

    # The oldest arm64 asset is built on macOS 14, so that is the floor.
    depends_on macos: :sonoma
  end
  on_intel do
    sha256 "41003617ab4f7784394b5ddea7ce51b3e0838e8cfc8166ad1a378b2eda3b583c"

    url "https://github.com/mpv-player/mpv/releases/download/v#{version}/mpv-v#{version}-macos-15-intel.zip"

    # Intel ships one asset only, built on macOS 15.
    depends_on macos: :sequoia
  end

  name "mpv"
  desc "Media player based on MPlayer and mplayer2"
  homepage "https://mpv.io/"

  livecheck do
    url "https://github.com/mpv-player/mpv"
    strategy :github_latest
  end

  # The release zip holds a single mpv.tar.gz, which in turn holds mpv.app.
  container nested: "mpv.tar.gz"

  app "mpv.app"
  # The CLI: link the bundle's own binary into the Homebrew prefix. The `mpv`
  # formula must not be installed next to this: both want /opt/homebrew/bin/mpv,
  # and Homebrew then warns "skipping link" and leaves the formula's symlink in
  # place, which would quietly keep `mpv` on PATH pointing at the formula.
  #
  # The link sits outside the bundle, so the bundled Vulkan loader cannot find
  # its MoltenVK ICD from it: launch the app for `vo=gpu-next`, or point
  # VK_ICD_FILENAMES at the bundled ICD.
  binary "#{appdir}/mpv.app/Contents/MacOS/mpv"

  uninstall quit: "io.mpv"

  # mpv's settings live in ~/.config/mpv, which is user-managed outside Homebrew,
  # so zapping them would delete configuration this cask does not own. Only the
  # per-user Library state belongs to the app.
  zap trash: [
    "~/Library/Logs/mpv.log",
    "~/Library/Preferences/io.mpv.plist",
    "~/Library/Preferences/mpv.plist",
    "~/Library/Saved Application State/io.mpv.savedState",
  ]

  # Homebrew quarantines cask downloads, and the bundle is ad-hoc signed with no
  # Developer ID, so Gatekeeper refuses the first launch. Nothing here can fix the
  # signature from this side; say how to get past it once. The linked `mpv` on
  # PATH is not launched as a bundle, so it runs regardless.
  caveats <<~EOS
    mpv is ad-hoc signed, not notarized, so macOS cannot verify who built it.
    Homebrew quarantines the download, so Gatekeeper blocks the first launch of
    the app; `mpv` on PATH still runs. Approve the app once in System Settings >
    Privacy & Security > Open Anyway, or clear the attribute yourself:

      xattr -dr com.apple.quarantine /Applications/mpv.app
  EOS
end
