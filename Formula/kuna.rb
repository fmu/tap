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
      url "https://github.com/Noelo-Lab/kuna/releases/download/v1.1004/kuna-v1.1004-macos-arm64.tar.gz"
      sha256 "2aa1c60dea9ab7b02d4fae3da6a200f0d8556eae2d0bbdb4c74ffda27eebf7d5"
    end

    on_intel do
      url "https://github.com/Noelo-Lab/kuna/releases/download/v1.1004/kuna-v1.1004-macos-x86_64.tar.gz"
      sha256 "be369d8eac49ed14ba8949f9a1e1bffff1fe2bd148026c5a6cb2c087398e0745"
    end
  end

  on_linux do
    on_intel do
      url "https://github.com/Noelo-Lab/kuna/releases/download/v1.1004/kuna-v1.1004-linux-x86_64.tar.gz"
      sha256 "6bcf6409f3c6832d800d49652707c9bf76e3b95056f0484e32e2822da5a5c078"
    end

    on_arm do
      url "https://github.com/Noelo-Lab/kuna/releases/download/v1.1004/kuna-v1.1004-linux-arm64.tar.gz"
      sha256 "e33099069846abb6d49873dc9e2a1bf65cc579757f2e9590b3298554ccc59785"
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
