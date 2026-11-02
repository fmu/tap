class Qwen3Embed < Formula
  desc "On-demand local Qwen3 embeddings and reranking, served by llama.cpp"
  homepage "https://github.com/fmu/qwen3-embed"
  url "https://github.com/fmu/qwen3-embed.git", tag: "v0.4.1", revision: "4083272977b0ece313a3e79adaa575ddc3f67d3a"
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
    # resolve the optional `setup-gbrain` integration's CLI from PATH, where
    # Homebrew's
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
      SHA-256 verified), then run the proxy at login:

        qwen3-embed setup               # both models, SHA-256 verified
        brew services start qwen3-embed
        brew services info qwen3-embed

      `model install reranker` installs just the reranker. The files live under
      ~/.local/share/qwen3-embed/models by default. The proxy starts each model
      on first use and unloads it after its own idle window: the embedding
      server follows the active mode's TTL, the reranker has its own
      reranker.ttlSeconds. The two processes are independent, so one being
      resident never keeps the other loaded.

      `serve` needs only bun and llama.cpp; gbrain is optional and not a
      dependency of this formula. Only the separate gbrain integration uses it:

        qwen3-embed setup-gbrain        # configure gbrain and backfill

      `setup-gbrain` writes gbrain's provider configuration (embedding and
      reranker URLs against the same loopback endpoint) and runs while
      `gbrain serve` is stopped. Install gbrain from the same tap
      (`brew install gbrain`) or keep your own copy on PATH; a global npm/bun
      install lands in #{HOMEBREW_PREFIX}/bin, which the qwen3-embed wrapper
      already includes.
    EOS
  end

  test do
    assert_match "Usage:", shell_output("#{bin}/qwen3-embed --help")
    assert_match "reranker", shell_output("#{bin}/qwen3-embed --help")
    assert_match "setup-gbrain", shell_output("#{bin}/qwen3-embed --help")

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
