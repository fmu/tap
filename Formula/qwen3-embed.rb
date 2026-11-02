class Qwen3Embed < Formula
  desc "On-demand local Qwen3 embeddings and reranking, served by llama.cpp"
  homepage "https://github.com/fmu/qwen3-embed"
  url "https://github.com/fmu/qwen3-embed.git", tag: "v0.3.0", revision: "e48d7b233e297da812eb7063147e0af24b9d192f"
  head "https://github.com/fmu/qwen3-embed.git", branch: "main"

  depends_on "bun"
  depends_on "llama.cpp"

  def install
    # The proxy spawns `llama-server` directly, so point it at the Homebrew keg
    # instead of the reference machine's /opt/homebrew path. Patch before
    # installing the tree: `install` moves files out of the build directory.
    llama_server = formula_opt_bin("llama.cpp")/"llama-server"
    inreplace "src/config.ts", '"/opt/homebrew/bin/llama-server"', %Q("#{llama_server}")

    # Do not let the Homebrew install silently pick up a Nix-managed gbrain;
    # resolve the optional `setup` integration's CLI from PATH, where Homebrew's
    # own bin directory comes first.
    inreplace "src/config.ts", <<~OLD, <<~NEW
      function defaultGbrainBin(): string {
        const nixProfile = join(home, ".nix-profile/bin/gbrain");
        return existsSync(nixProfile) ? nixProfile : "gbrain";
      }
    OLD
      function defaultGbrainBin(): string {
        return "gbrain";
      }
    NEW

    libexec.install "src"
    doc.install "README.md"

    (bin/"qwen3-embed").write <<~SH
      #!/bin/bash
      export PATH="#{formula_opt_bin("llama.cpp")}:#{HOMEBREW_PREFIX}/bin:/usr/bin:/bin:/usr/sbin:/sbin:${PATH}"
      exec "#{formula_opt_bin("bun")}/bun" "#{opt_libexec}/src/cli.ts" "$@"
    SH
    chmod 0755, bin/"qwen3-embed"
  end

  service do
    run [opt_bin/"qwen3-embed", "serve"]
    keep_alive true
    working_dir var
    log_path var/"log/qwen3-embed.log"
    error_log_path var/"log/qwen3-embed.log"
  end

  def caveats
    <<~EOS
      Install the models once (embedding ~3.3 GB, reranker ~0.6 GB, both
      SHA-256 verified):

        qwen3-embed model install               # both models
        qwen3-embed model install reranker      # reranker only (optional)

      They live under ~/.local/share/qwen3-embed/models by default. The proxy
      starts each model on first use and unloads it after its own idle window:
      the embedding server follows the active mode's TTL, the reranker has its
      own reranker.ttlSeconds. The two processes are independent, so one being
      resident never keeps the other loaded.

      `serve` needs only bun and llama.cpp; gbrain is optional. `setup` writes
      gbrain's provider configuration, and `gbrain` is not a dependency of this
      formula: install it from the same tap (`brew install gbrain`) or keep
      your own copy on PATH. A global npm/bun install lands in
      #{HOMEBREW_PREFIX}/bin, which the qwen3-embed wrapper already includes.

      Then, only if you use gbrain, point it at this service and run the proxy
      at login:

        qwen3-embed setup
        brew services start qwen3-embed

      `setup` configures both the embedding and reranker provider URLs against
      the same loopback endpoint (#{HOMEBREW_PREFIX} installs both models).
    EOS
  end

  test do
    assert_match "Usage:", shell_output("#{bin}/qwen3-embed --help")
    assert_match "reranker", shell_output("#{bin}/qwen3-embed --help")

    (testpath/"config.json").write <<~JSON
      {
        "listenPort": 0,
        "upstreamPort": 9,
        "stateDir": "#{testpath}/state"
      }
    JSON
    ENV["QWEN3_EMBED_CONFIG"] = (testpath/"config.json").to_s

    output = shell_output("#{bin}/qwen3-embed status --json")
    assert_match '"ok": false', output
    assert_match '"state": "stopped"', output
    assert_match '"reranker"', output
  end
end
