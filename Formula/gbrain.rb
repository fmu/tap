class Gbrain < Formula
  desc "Postgres-native personal knowledge brain with hybrid RAG search"
  homepage "https://github.com/garrytan/gbrain"
  license "MIT"

  # Upstream publishes Bun-compiled binaries for macOS arm64 and Linux x86_64
  # only, under the same asset names that `gbrain upgrade` targets. A scheduled
  # workflow re-pins this formula when upstream tags a release.
  if OS.mac?
    depends_on arch: :arm64

    url "https://github.com/garrytan/gbrain/releases/download/v0.60.553.0/gbrain-darwin-arm64"
    sha256 "e7b90d6c95c91c174f82313fc766be02b31566c28a38ad1a5dde679ce3460cc5"
  else
    depends_on arch: :x86_64

    url "https://github.com/garrytan/gbrain/releases/download/v0.60.553.0/gbrain-linux-x64"
    sha256 "c02db6b27d0f1e4fa346009fe9b58f7fe2a7c9fb2bca7fe3605a852c9d2e4506"
  end

  livecheck do
    url :homepage
    strategy :github_latest
  end

  skip_clean "bin/gbrain"

  def install
    if OS.mac?
      bin.install "gbrain-darwin-arm64" => "gbrain"
    else
      bin.install "gbrain-linux-x64" => "gbrain"
    end
    # gbrain's own `gbrain upgrade` atomically replaces the binary in its keg.
    # Homebrew forces keg executables to 0555 unless the path is skipped from
    # cleaning (see the class-level skip_clean), so keep this one writable.
    chmod 0755, bin/"gbrain"
  end

  def caveats
    <<~EOS
      This is upstream's self-contained binary. gbrain keeps its own update
      channel: `gbrain upgrade` replaces the binary in this Homebrew keg in
      place, and the tap's scheduled workflow keeps the formula pinned to the
      latest upstream release, so `brew upgrade gbrain` tracks upstream too.
      In-place self-update needs a user-writable Homebrew prefix.

      Upstream publishes binaries for macOS arm64 and Linux x86_64 only.

      This is not the unrelated npm `gbrain` package. Start a brain with:

        gbrain init --pglite
        gbrain doctor

      Docs: https://github.com/garrytan/gbrain/blob/master/docs/INSTALL.md
    EOS
  end

  test do
    assert_match(/\Agbrain \d+\.\d+\.\d+(?:\.\d+)?/, shell_output("#{bin}/gbrain --version"))
  end
end
