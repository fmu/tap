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
      url "https://github.com/Noelo-Lab/kuna/releases/download/v1.992/kuna-v1.992-macos-arm64.tar.gz"
      sha256 "8cb16d3a2573a6edb3abdfa3210abb884ed85bf6e9b4d5fb5259b68ab5fe5de9"
    end

    on_intel do
      url "https://github.com/Noelo-Lab/kuna/releases/download/v1.992/kuna-v1.992-macos-x86_64.tar.gz"
      sha256 "295abe350b55d0d950d936d5f35693f7f93193d5c279706c1b80d96941bde95e"
    end
  end

  on_linux do
    on_intel do
      url "https://github.com/Noelo-Lab/kuna/releases/download/v1.992/kuna-v1.992-linux-x86_64.tar.gz"
      sha256 "f87d002309220de1f2f20479a7324b80a3779ba30d3624e1071091b51e2c0719"
    end

    on_arm do
      url "https://github.com/Noelo-Lab/kuna/releases/download/v1.992/kuna-v1.992-linux-arm64.tar.gz"
      sha256 "8a6057cf507d7576fa0839de1b43dc2178ce6d119760a5408819a3d814893420"
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
