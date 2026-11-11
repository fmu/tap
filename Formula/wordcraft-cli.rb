# The headless half of the WordCraft release. The app is the `wordcraft` cask
# in homebrew-cask: both are built from one upstream tag, so this formula is
# pinned to the release the app is on and the scheduled bump follows the same
# GitHub release stream the cask tracks.
#
# Upstream publishes the CLI as a self-contained universal macOS binary next to
# the app artifacts, so the formula installs that release asset instead of
# compiling the engine with Rust: `brew upgrade` is a download rather than a
# multi-minute `cargo install`, and the release binary carries the optional
# extra fonts from storytold/craft-fonts. `convert`, `info`, `text`, `inspect`,
# `render`, `run`, `commands`, `parity`, `mcp` and `zotero` are the same engine
# the app uses; `run` editing the built-in sample and saving it as .docx, then
# converting it to PDF and reading the text back, exercises the document model,
# saver, importer and exporter in `brew test` without starting the desktop app.
#
# The asset is macOS-only (upstream ships no Linux CLI binary, and the Linux
# artifacts are GUI bundles), so the formula declares macOS instead of
# installing a Mach-O binary on a host that cannot run it.
class WordcraftCli < Formula
  desc "Headless WordCraft engine to write, edit and export documents"
  homepage "https://getartcraft.com/apps/wordcraft"
  url "https://github.com/storytold/wordcraft/releases/download/v0.18.0/wordcraft-cli-0.18.0-macos-universal.zip"
  sha256 "7df280ca934307fd80d389e2075bf00a042e09880f7200937b1829c8c5f30f19"
  license any_of: ["MIT", "Apache-2.0"]

  livecheck do
    url :stable
    strategy :github_latest
  end

  depends_on :macos

  def install
    bin.install "wordcraft-cli"
  end

  test do
    assert_match version.to_s, shell_output("#{bin}/wordcraft-cli --version")
    assert_match "format.bold", shell_output("#{bin}/wordcraft-cli commands")

    # The sample document is compiled into the engine: insert text, save it as
    # .docx, convert it to PDF, then read the text back.
    system bin/"wordcraft-cli", "run", "--template", "sample",
           "--cmd", 'text.insert={"text":"Hello brew"}', "--save", "sample.docx"
    system bin/"wordcraft-cli", "convert", "sample.docx", "sample.pdf"

    assert_operator (testpath/"sample.docx").size, :>, 1000
    assert_equal "%PDF".b, (testpath/"sample.pdf").binread(4)
    assert_match "Hello brew", shell_output("#{bin}/wordcraft-cli text sample.docx")
    assert_match "The Open Studio Handbook", shell_output("#{bin}/wordcraft-cli text sample.docx")
  end
end
