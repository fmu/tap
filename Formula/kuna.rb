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
      url "https://github.com/Noelo-Lab/kuna/releases/download/v1.1007/kuna-v1.1007-macos-arm64.tar.gz"
      sha256 "4cb6ab7d02f9e364c61776b752f0ec89e9ba9fb9b1a033dd2a9a396f74b45087"
    end

    on_intel do
      url "https://github.com/Noelo-Lab/kuna/releases/download/v1.1007/kuna-v1.1007-macos-x86_64.tar.gz"
      sha256 "8431860363f57a6ae6b492e9788c47b95b5d75efc9c667757e89150f853307eb"
    end
  end

  on_linux do
    on_intel do
      url "https://github.com/Noelo-Lab/kuna/releases/download/v1.1007/kuna-v1.1007-linux-x86_64.tar.gz"
      sha256 "45d99f4c2f7289c739cf14654d1266d9ce775bd109425531a3b418a1526fc0b0"
    end

    on_arm do
      url "https://github.com/Noelo-Lab/kuna/releases/download/v1.1007/kuna-v1.1007-linux-arm64.tar.gz"
      sha256 "e6a321a61105284bda8b1118307a9d6b301ce42b5bedf3d986aa73ea1c27e878"
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
