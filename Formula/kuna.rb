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
      url "https://github.com/Noelo-Lab/kuna/releases/download/v1.1008/kuna-v1.1008-macos-arm64.tar.gz"
      sha256 "62113622a490024e92ee3cc50ab3d8c961e9c0c8fdf9b68ac65fdbc58a59f424"
    end

    on_intel do
      url "https://github.com/Noelo-Lab/kuna/releases/download/v1.1008/kuna-v1.1008-macos-x86_64.tar.gz"
      sha256 "7be9c80ea52428cd49f63daf3e2858729d204c279df4afafb55b5d82972b252a"
    end
  end

  on_linux do
    on_intel do
      url "https://github.com/Noelo-Lab/kuna/releases/download/v1.1008/kuna-v1.1008-linux-x86_64.tar.gz"
      sha256 "e34f0bb176e0cb228edf2ca1ca734b57334461148cc685fb66c66a8d92d597d5"
    end

    on_arm do
      url "https://github.com/Noelo-Lab/kuna/releases/download/v1.1008/kuna-v1.1008-linux-arm64.tar.gz"
      sha256 "4cc560dc2fdcee654ca4709b44d1e44634f337ad3bd903763f5a64af5173b1a3"
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
