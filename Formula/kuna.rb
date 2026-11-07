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
      url "https://github.com/Noelo-Lab/kuna/releases/download/v1.993/kuna-v1.993-macos-arm64.tar.gz"
      sha256 "cc1d9525dba79f973052cc7822ee3dae5402cceb2784e23bd57ccc312ec7717b"
    end

    on_intel do
      url "https://github.com/Noelo-Lab/kuna/releases/download/v1.993/kuna-v1.993-macos-x86_64.tar.gz"
      sha256 "f7113c5267618ea0bfacb60d44352d2042ff5ee706c3d68df55e5c1f1dd916de"
    end
  end

  on_linux do
    on_intel do
      url "https://github.com/Noelo-Lab/kuna/releases/download/v1.993/kuna-v1.993-linux-x86_64.tar.gz"
      sha256 "ca40af8586fbbb0fe88698daae57b9020c621587cad09550de90b959ff0320cc"
    end

    on_arm do
      url "https://github.com/Noelo-Lab/kuna/releases/download/v1.993/kuna-v1.993-linux-arm64.tar.gz"
      sha256 "06b8845f6999708aad78d1dabdf0ec7452072222f43710b73c550f2941768992"
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
