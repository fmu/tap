# Latest upstream release of Kuna, the agent-first decompiler. REA pins the
# release it verifies in Formula/kuna@<release>.rb; this formula tracks upstream's
# latest release for standalone use and is bumped by `scripts/bump/kuna.py`.
#
# The release is one self-contained executable per platform; it links only the
# system libraries, so there is nothing to compile and nothing else to depend on.
class Kuna < Formula
  desc "Agent-first decompiler for x86-64, AArch64 and ARM binaries"
  homepage "https://github.com/Noelo-Lab/kuna"
  license "Apache-2.0"

  livecheck do
    url :stable
    strategy :github_latest
  end

  on_macos do
    on_arm do
      url "https://github.com/Noelo-Lab/kuna/releases/download/v1.1005/kuna-v1.1005-macos-arm64.tar.gz"
      sha256 "b49897086e608b69e58c2b0abdc51113fe326c818dbd1bfed2a8b066e2ff5252"
    end

    on_intel do
      url "https://github.com/Noelo-Lab/kuna/releases/download/v1.1005/kuna-v1.1005-macos-x86_64.tar.gz"
      sha256 "ff43bb837adbabf7bee443db27da6c99063e5e8a448820c23ae2c1b9111f74b1"
    end
  end

  on_linux do
    on_intel do
      url "https://github.com/Noelo-Lab/kuna/releases/download/v1.1005/kuna-v1.1005-linux-x86_64.tar.gz"
      sha256 "a58141dc2a483e72e22c8e7da1e933f48a3205e8f9255ea8c8acd6bb19506f55"
    end

    on_arm do
      url "https://github.com/Noelo-Lab/kuna/releases/download/v1.1005/kuna-v1.1005-linux-arm64.tar.gz"
      sha256 "cc9c8ac864e53d723c6f189739196c3a0ee84a3efa3714ab0886080699f16574"
    end
  end

  def install
    bin.install "kuna"
    doc.install "LICENSE", "NOTICE"
  end

  test do
    assert_match "kuna #{version}", shell_output("#{bin}/kuna --version")
  end
end
