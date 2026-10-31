class GbrainEmbed < Formula
  desc "On-demand local embeddings and reranking for gbrain, served by llama.cpp"
  homepage "https://github.com/fmu/gbrain-embed"
  url "https://github.com/fmu/gbrain-embed.git", tag: "v0.2.0"
  head "https://github.com/fmu/gbrain-embed.git", branch: "main"

  depends_on "bun"
  depends_on "llama.cpp"

  def install
    # The proxy spawns `llama-server` and the `gbrain` CLI directly, so point it
    # at the Homebrew keg instead of the reference machine's /opt/homebrew path.
    # Patch before installing the tree: `install` moves files out of the build
    # directory.
    llama_server = formula_opt_bin("llama.cpp")/"llama-server"
    inreplace "src/config.ts", '"/opt/homebrew/bin/llama-server"', %Q("#{llama_server}")

    # Do not let the Homebrew install silently pick up a Nix-managed gbrain;
    # resolve it from PATH, where Homebrew's own bin directory comes first.
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

    (bin/"gbrain-embed").write <<~SH
      #!/bin/bash
      export PATH="#{formula_opt_bin("llama.cpp")}:#{HOMEBREW_PREFIX}/bin:/usr/bin:/bin:/usr/sbin:/sbin:${PATH}"
      exec "#{formula_opt_bin("bun")}/bun" "#{opt_libexec}/src/cli.ts" "$@"
    SH
    chmod 0755, bin/"gbrain-embed"
  end

  service do
    run [opt_bin/"gbrain-embed", "serve"]
    keep_alive true
    working_dir var
    log_path var/"log/gbrain-embed.log"
    error_log_path var/"log/gbrain-embed.log"
  end

  def caveats
    <<~EOS
      Install the models once (embedding ~3.3 GB, reranker ~0.6 GB, both
      SHA-256 verified):

        gbrain-embed model install               # both models
        gbrain-embed model install reranker      # reranker only (optional)

      They live under ~/.local/share/gbrain-embed/models by default and are
      shared by `gbrain serve`. The proxy starts each model on first use and
      unloads it after its own idle window: the embedding server follows the
      active mode's TTL, the reranker has its own reranker.ttlSeconds. The two
      processes are independent, so one being resident never keeps the other
      loaded.

      `gbrain` itself is not a Homebrew formula. Install it separately and keep
      it on PATH; a global npm/bun install lands in #{HOMEBREW_PREFIX}/bin,
      which the gbrain-embed wrapper already includes.

      Then point gbrain at this service and run it at login:

        gbrain-embed setup
        brew services start gbrain-embed

      `setup` configures both the embedding and reranker provider URLs against
      the same loopback endpoint (#{HOMEBREW_PREFIX} installs both models).
    EOS
  end

  test do
    assert_match "Usage:", shell_output("#{bin}/gbrain-embed --help")
    assert_match "reranker", shell_output("#{bin}/gbrain-embed --help")

    (testpath/"config.json").write <<~JSON
      {
        "listenPort": 0,
        "upstreamPort": 9,
        "stateDir": "#{testpath}/state"
      }
    JSON
    ENV["GBRAIN_EMBED_CONFIG"] = (testpath/"config.json").to_s

    output = shell_output("#{bin}/gbrain-embed status --json")
    assert_match '"ok": false', output
    assert_match '"state": "stopped"', output
    assert_match '"reranker"', output
  end
end
