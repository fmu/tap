# Skippy is Mesh-LLM's standalone model-serving product: a CLI that manages
# models and native runtimes, serves an OpenAI/Anthropic-compatible API, and runs
# explicit split stages without the mesh networking that mesh-llm adds.
#
# Upstream publishes a prebuilt `skippy` CLI for macOS arm64. Note that the
# stable release tags (v0.78.1 and earlier) carry no skippy asset: the CLI is
# only attached to the rolling-preview releases, so this formula pins the
# newest release that actually ships one. `scripts/bump/skippy.py` follows that
# rule. The binary downloads a matching native runtime and models on first use.
class Skippy < Formula
  desc "Standalone model-serving CLI with OpenAI-compatible APIs"
  homepage "https://github.com/Mesh-LLM/mesh-llm"
  url "https://github.com/Mesh-LLM/mesh-llm/releases/download/v0.79.0/skippy-v0.79.0-darwin-aarch64-cli.tar.gz"
  version "0.79.0"
  sha256 "3afedf78ba1fdab8d56541c82301e11656e8a08b210dd7a3987232f225c2f5ce"
  license any_of: ["MIT", "Apache-2.0"]

  depends_on arch: :arm64

  def install
    bin.install "skippy"
    libexec.install "host-imports.json"
  end

  def caveats
    <<~EOS
      `skippy serve` installs a verified native runtime (and downloads models)
      on first use; both are cached under the usual Mesh-LLM data directory.
      Run `skippy doctor` to inspect the hardware and runtime it selected.
    EOS
  end

  test do
    assert_match version.to_s, shell_output("#{bin}/skippy --version")
    assert_match "Usage: skippy", shell_output("#{bin}/skippy --help")
    assert_path_exists libexec/"host-imports.json"
  end
end
