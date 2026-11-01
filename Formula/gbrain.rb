class Gbrain < Formula
  desc "Postgres-native personal knowledge brain with hybrid RAG search"
  homepage "https://github.com/garrytan/gbrain"
  license "MIT"

  # Upstream publishes Bun-compiled binaries for macOS arm64 and Linux x86_64
  # only, under the same asset names that `gbrain upgrade` targets. A scheduled
  # workflow re-pins this formula when upstream tags a release.
  if OS.mac?
    depends_on arch: :arm64

    url "https://github.com/garrytan/gbrain/releases/download/v0.60.539.0/gbrain-darwin-arm64"
    sha256 "45e8563e77184b83e1cc0ab2bd981182142254bfc34d037f769f3e7107d5db92"
  else
    depends_on arch: :x86_64

    url "https://github.com/garrytan/gbrain/releases/download/v0.60.539.0/gbrain-linux-x64"
    sha256 "393d48d8e52a52cec9f6e3aae145d60eca4257e4246b3246c6c25adebeeab2c4"
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
