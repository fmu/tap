# shurectl is upstream's terminal UI for Shure USB microphones and audio
# interfaces: gain, mute, EQ, compressor and four preset slots on the device
# itself, plus one-shot `--mute`, `--preset` and `--json` commands for scripts
# and Stream Deck buttons.
#
# Upstream's own tap (humblemonk/shurectl) builds the tool from source with
# cargo. Upstream also attaches a universal macOS binary to each release, so
# this formula installs that asset instead: `brew install` and `brew upgrade`
# are downloads rather than a Rust compile, and no toolchain is needed. The
# binary is only ad-hoc (linker) signed, not Developer ID signed, so the raw
# release archive trips Gatekeeper; Homebrew-installed files carry no quarantine
# attribute, so this keg runs without the `xattr -d com.apple.quarantine` step
# the release page asks for.
#
# Upstream publishes Linux and Windows archives from the same tag. The formula
# is macOS-only because the universal asset is the one this tap's CI can
# install and test.
class Shurectl < Formula
  desc "Terminal UI configurator for Shure USB audio interfaces and microphones"
  homepage "https://github.com/Humblemonk/shurectl"
  url "https://github.com/Humblemonk/shurectl/releases/download/v2.17.0/shurectl-v2.17.0-universal-apple-darwin.tar.gz"
  sha256 "afd17796c65d89d5f52bfbf2665a1ba8033253e59bf53f5d72389feb9fbf44d3"
  license "GPL-3.0-only"

  livecheck do
    url :stable
    strategy :github_latest
  end

  depends_on :macos

  def install
    bin.install "shurectl"
    doc.install "LICENSE", "README.md", "CHANGELOG.md"
  end

  test do
    assert_match "shurectl #{version}", shell_output("#{bin}/shurectl --version")
    assert_match "TUI configurator for Shure", shell_output("#{bin}/shurectl --help")
  end
end
