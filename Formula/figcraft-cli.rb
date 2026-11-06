# The headless half of the FigCraft release. The app is the `figcraft` cask in
# homebrew-cask: both are built from one upstream tag, so this formula is
# pinned to the release the app is on and the scheduled bump follows the same
# GitHub release stream the cask tracks.
#
# Upstream publishes the CLI as a self-contained universal macOS binary next to
# the app artifacts, so the formula installs that release asset instead of
# compiling the engine with Rust: `brew upgrade` is a download rather than a
# multi-minute `cargo install`, and the release binary carries the optional
# fonts from storytold/craft-fonts. `info`, `export`, `convert`, `render`,
# `run`, `commands`, `mcp`, `plugin`, `connect` and `perf` are the same engine
# the app uses; `run` building a frame from a command script, then exporting it
# to PNG, exercises the document model and renderer in `brew test` without
# starting the desktop app.
#
# The asset is macOS-only (upstream ships no Linux CLI binary, and the Linux
# artifacts are GUI bundles), so the formula declares macOS instead of
# installing a Mach-O binary on a host that cannot run it.
class FigcraftCli < Formula
  desc "Headless FigCraft engine to design, prototype and export interfaces"
  homepage "https://getartcraft.com/apps/figcraft"
  url "https://github.com/storytold/figcraft/releases/download/v0.16.0/figcraft-cli-0.16.0-macos-universal.zip"
  sha256 "48a0f350fccd1ac22d744645f09cba00f9795ed3c4ef1273c67551387ccdf63b"
  license any_of: ["MIT", "Apache-2.0"]

  livecheck do
    url :stable
    strategy :github_latest
  end

  depends_on :macos

  def install
    bin.install "figcraft-cli"
  end

  test do
    assert_match version.to_s, shell_output("#{bin}/figcraft-cli --version")
    assert_match "frame.create", shell_output("#{bin}/figcraft-cli commands")

    # A frame and a rectangle from a command script: the headless session
    # builds and saves the document, then exports the frame to PNG.
    (testpath/"script.json").write <<~JSON
      [
        {"command": "frame.create", "params": {"x": 0, "y": 0, "width": 200, "height": 200}},
        {"command": "shape.rectangle", "params": {"x": 20, "y": 20, "width": 100, "height": 50}}
      ]
    JSON
    system bin/"figcraft-cli", "run", "script.json", "--out", "page.figcraft"
    system bin/"figcraft-cli", "export", "--out", "page.png", "page.figcraft"

    assert_operator (testpath/"page.figcraft").size, :>, 1000
    assert_equal "\x89PNG".b, (testpath/"page.png").binread(4)
    assert_operator (testpath/"page.png").size, :>, 500
  end
end
