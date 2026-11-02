# The headless half of the SolidCraft release. The app is the `solidcraft` cask
# in homebrew-cask: both are built from one upstream tag, so the formula follows
# the same GitHub release stream the cask tracks.
#
# Upstream publishes the CLI as a self-contained universal macOS binary next to
# the app artifacts, so the formula installs that release asset instead of
# compiling the engine with Rust: `brew upgrade` is a download rather than a
# multi-minute `cargo install`. `run`, `eval`, `script`, `snapshot`, `render`,
# `exec`, `commands`, `mcp`, `bench-open` and `bench-agent` are the same kernel
# the app uses; `run` building a box from a command script, exporting it to STEP
# and evaluating it back exercises the solid kernel and the STEP writer in
# `brew test` without starting the desktop app.
#
# The archive also carries the deprecated `solvecraft-cli` alias, which this
# formula does not install (upstream says it will be removed).
#
# The asset is macOS-only (upstream ships no Linux CLI binary, and the Linux
# artifacts are GUI bundles), so the formula declares macOS instead of
# installing a Mach-O binary on a host that cannot run it.
class SolidcraftCli < Formula
  desc "Headless SolidCraft engine to model, evaluate and export parametric 3D CAD"
  homepage "https://solidcraft.io/"
  url "https://github.com/tangency-labs/solidcraft/releases/download/v0.30.0/solidcraft-cli-0.30.0-macos-universal.zip"
  sha256 "e2e594c1ba5cfbf0a01dec33cf3b13fc946307ceb846b773adaddedecaa90435"
  license any_of: ["MIT", "Apache-2.0"]

  livecheck do
    url :stable
    strategy :github_latest
  end

  depends_on :macos

  def install
    bin.install "solidcraft-cli"
  end

  test do
    assert_match version.to_s, shell_output("#{bin}/solidcraft-cli --version")
    assert_match "solid.box", shell_output("#{bin}/solidcraft-cli commands")

    # A 100 × 60 × 20 mm box from a command script, exported to STEP and
    # measured back: the headless kernel builds and evaluates the solid.
    (testpath/"box.json").write <<~JSON
      [
        {"command": "solid.box", "params": {"length": 100, "width": 60, "height": 20}}
      ]
    JSON
    system bin/"solidcraft-cli", "run", "box.json", "--out", "box.step"

    assert_operator (testpath/"box.step").size, :>, 1000
    assert_match "ISO-10303-21", (testpath/"box.step").read
    assert_match '"volume_mm3": 120000.0',
                 shell_output("#{bin}/solidcraft-cli eval --in box.step")
  end
end
