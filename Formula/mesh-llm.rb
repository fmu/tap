# Mesh-LLM pools GPUs and memory across machines and exposes them as one
# OpenAI-compatible API. Its release bundle is a prebuilt `mesh-llm` host binary
# plus a verified Metal native runtime; the mesh networking and console live in
# the host binary, while Skippy owns the model-serving runtime it embeds.
#
# Skippy is also packaged separately in this tap (`skippy`); mesh-llm depends on
# it so both products of the workspace are installed together, and so the
# standalone CLI is available for split-stage and runtime work.
#
# The native runtime manifest records a SHA-256 for every runtime file and the
# loader refuses a runtime whose files changed. Keg relocation rewrites install
# names and re-signs every Mach-O file, which invalidates those hashes, so the
# runtime is staged as an archive here and unpacked in `post_install_steps`,
# after relocation. The runtime needs no relocation itself: its libraries link
# only against system libraries and resolve each other through @loader_path.
class MeshLlm < Formula
  desc "Distributed AI/LLM runtime that pools compute across machines"
  homepage "https://github.com/Mesh-LLM/mesh-llm"
  url "https://github.com/Mesh-LLM/mesh-llm/releases/download/v0.78.1/mesh-llm-v0.78.1-aarch64-apple-darwin.tar.gz"
  sha256 "a00fd8c7c3d4cf5a543c83b2034dcf7a7cfe02198f9056faa09305d774ae5001"
  license any_of: ["MIT", "Apache-2.0"]

  depends_on arch: :arm64
  depends_on "skippy"

  def install
    bin.install "mesh-llm"
    libexec.install "product-manifest.json"
    libexec.install "host-imports.json"
    libexec.install "plugins" if File.directory?("plugins")

    system "tar", "czf", libexec/"native-runtime.tar.gz", "native-runtimes"
  end

  post_install_steps do
    run "/usr/bin/tar",
        args:           ["xzf", "{{libexec}}/native-runtime.tar.gz", "-C", "{{libexec}}"],
        writable_paths: ["{{libexec}}"]
  end

  def caveats
    <<~EOS
      `mesh-llm setup` bootstraps a node; `mesh-llm serve --auto` starts one.
      Models and the native runtime are cached under the Mesh-LLM data
      directory. The OpenAI-compatible API is served on http://localhost:9337/v1.
    EOS
  end

  test do
    require "digest"
    require "json"

    assert_path_exists libexec/"product-manifest.json"
    manifest = JSON.parse((libexec/"product-manifest.json").read)
    assert_equal manifest.fetch("host").fetch("sha256"), Digest::SHA256.file(bin/"mesh-llm").hexdigest
    assert_match version.to_s, shell_output("#{bin}/mesh-llm --version")

    # `runtime list` prints a warning naming any runtime it rejected and still
    # exits 0, so assert that the runtime was actually discovered rather than
    # matching text that a rejection also prints.
    runtimes = shell_output("#{bin}/mesh-llm runtime list")
    assert_match "meshllm-native-runtime-darwin-aarch64-metal", runtimes
    refute_match "malformed native runtime", runtimes
    refute_match "No local native runtimes found", runtimes

    assert_match "Usage: mesh-llm", shell_output("#{bin}/mesh-llm --help")
  end
end
