class GbrainEmbed < Formula
  desc "On-demand local embeddings for gbrain, served by llama.cpp"
  homepage "https://github.com/fmu/gbrain-embed"
  url "https://github.com/fmu/gbrain-embed/archive/refs/tags/v0.1.0.tar.gz"
  sha256 "2a881015167ffea9e8f0e793ee25500298267109b1f162a8031b57f8efc5c377"
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
      Install the embedding model once (3.3 GB, SHA-256 verified):

        gbrain-embed model install

      It lives under ~/.local/share/gbrain-embed/models by default and is
      shared by `gbrain serve`.

      `gbrain` itself is not a Homebrew formula. Install it separately and keep
      it on PATH; a global npm/bun install lands in #{HOMEBREW_PREFIX}/bin,
      which the gbrain-embed wrapper already includes.

      Then point gbrain at this service and run it at login:

        gbrain-embed setup
        brew services start gbrain-embed
    EOS
  end

  test do
    assert_match "Usage:", shell_output("#{bin}/gbrain-embed --help")

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
  end
end
