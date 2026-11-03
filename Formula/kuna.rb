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
      url "https://github.com/Noelo-Lab/kuna/releases/download/v1.990/kuna-v1.990-macos-arm64.tar.gz"
      sha256 "f1469757ef329542951640439198afe836e1ead90e3bf3d544b10e27d4e6ed3e"
    end

    on_intel do
      url "https://github.com/Noelo-Lab/kuna/releases/download/v1.990/kuna-v1.990-macos-x86_64.tar.gz"
      sha256 "58886b210d42dc3f40fff202b979cbf8bef7ddc663447d09f52c97ccdd1fc1d1"
    end
  end

  on_linux do
    on_intel do
      url "https://github.com/Noelo-Lab/kuna/releases/download/v1.990/kuna-v1.990-linux-x86_64.tar.gz"
      sha256 "4860603084da39dcdebeb9155116a886f8294003af54cecdb6a687529f0b5f54"
    end

    on_arm do
      url "https://github.com/Noelo-Lab/kuna/releases/download/v1.990/kuna-v1.990-linux-arm64.tar.gz"
      sha256 "8492ccd011c51aeac670435ab00ac3166400ad65f41b0198b6d9689ef2c147b9"
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
