# The headless half of the DesignCraft release. The app is the `designcraft`
# cask in homebrew-cask: both are built from one upstream tag, so this formula
# is pinned to the release the app is on and the scheduled bump follows the same
# GitHub release stream the cask tracks.
#
# Upstream publishes the CLI as a self-contained universal macOS binary next to
# the app artifacts, so the formula installs that release asset instead of
# compiling the engine with Rust: `brew upgrade` is a download rather than a
# multi-minute `cargo install`, and the release binary carries the optional
# extra fonts from storytold/craft-fonts. `run`, `script`, `commands`,
# `describe`, `mcp`, `validate-pdf`, `perf` and `bench` are the same engine the
# app uses; `run --sample --export page.png` exercises layout and rendering in
# `brew test` without starting the desktop app.
#
# The asset is macOS-only (upstream ships no Linux CLI binary, and the Linux
# artifacts are GUI bundles), so the formula declares macOS instead of
# installing a Mach-O binary on a host that cannot run it.
class DesigncraftCli < Formula
  desc "Headless DesignCraft engine to lay out, edit and export documents"
  homepage "https://getartcraft.com/apps/designcraft"
  url "https://github.com/storytold/designcraft/releases/download/v0.20.0/designcraft-cli-0.20.0-macos-universal.zip"
  sha256 "5b0c94af5d0710f1f53a98c6b3f50819881002cac1b7263cc22d4150e4a131dd"
  license any_of: ["MIT", "Apache-2.0"]

  livecheck do
    url :stable
    strategy :github_latest
  end

  depends_on :macos

  def install
    bin.install "designcraft-cli"
  end

  test do
    assert_match version.to_s, shell_output("#{bin}/designcraft-cli --version")
    assert_match "frame.create", shell_output("#{bin}/designcraft-cli commands frame.create")

    # The sample magazine is compiled into the engine, so this lays out and
    # renders one page without needing the app or a document on disk.
    system bin/"designcraft-cli", "run", "--sample", "--export", "page.png"
    assert_equal "\x89PNG".b, (testpath/"page.png").binread(4)
    assert_operator (testpath/"page.png").size, :>, 1000
  end
end
