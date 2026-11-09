# The headless half of the VectorCraft release. The app is the `vectorcraft`
# cask in homebrew-cask: both are built from one upstream tag, so this formula
# is pinned to the release the app is on and the scheduled bump follows the same
# GitHub release stream the cask tracks.
#
# Upstream publishes the CLI as a self-contained universal macOS binary next to
# the app artifacts, so the formula installs that release asset instead of
# compiling the engine with Rust: `brew upgrade` is a download rather than a
# multi-minute `cargo install`, and the release binary carries the optional
# extra fonts from storytold/craft-fonts. `mcp`, `run`, `commands`, `convert`,
# `info`, `bench` and `perf` are the same engine the app uses; `run` creating a
# rectangle and exporting it to SVG exercises layout and rendering in
# `brew test` without starting the desktop app.
#
# The asset is macOS-only (upstream ships no Linux CLI binary, and the Linux
# artifacts are GUI bundles), so the formula declares macOS instead of
# installing a Mach-O binary on a host that cannot run it.
class VectorcraftCli < Formula
  desc "Headless VectorCraft engine to draw, edit and export vector artwork"
  homepage "https://getartcraft.com/apps/vectorcraft"
  url "https://github.com/storytold/vectorcraft/releases/download/v0.23.0/vectorcraft-cli-0.23.0-macos-universal.zip"
  sha256 "beab784c2971caa7fd5ab48058e2af69c3c8bf76ef8abfb78e36bdf5b76dee20"
  license any_of: ["MIT", "Apache-2.0"]

  livecheck do
    url :stable
    strategy :github_latest
  end

  depends_on :macos

  def install
    bin.install "vectorcraft-cli"
  end

  test do
    assert_match version.to_s, shell_output("#{bin}/vectorcraft-cli --version")
    assert_match "file.new", shell_output("#{bin}/vectorcraft-cli commands")

    # A new document plus one rectangle, exported to SVG: the headless engine
    # lays out and writes the file without needing the app or a document on disk.
    system bin/"vectorcraft-cli", "run",
           "--cmd", "file.new", "--params", '{"width":200,"height":200}',
           "--cmd", "shape.rectangle", "--params", '{"x":20,"y":20,"width":100,"height":50}',
           "--export", "page.svg"

    page = (testpath/"page.svg").read
    assert_match "<svg", page
    assert_match '<rect x="20"', page
  end
end
