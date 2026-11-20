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
      url "https://github.com/Noelo-Lab/kuna/releases/download/v1.1001/kuna-v1.1001-macos-arm64.tar.gz"
      sha256 "575f4599cb687ffe68884de01442b6a5b3018af809047b4d4aeffc1a9bf3eb57"
    end

    on_intel do
      url "https://github.com/Noelo-Lab/kuna/releases/download/v1.1001/kuna-v1.1001-macos-x86_64.tar.gz"
      sha256 "f572b9b6299c78f2f6b402915826fe56c80c82c7a0d6c3bc251135289e5ee013"
    end
  end

  on_linux do
    on_intel do
      url "https://github.com/Noelo-Lab/kuna/releases/download/v1.1001/kuna-v1.1001-linux-x86_64.tar.gz"
      sha256 "c1d1d99b033ab19a3b248ca4f1da74b995812dc0d6e96cb7e98753861e797086"
    end

    on_arm do
      url "https://github.com/Noelo-Lab/kuna/releases/download/v1.1001/kuna-v1.1001-linux-arm64.tar.gz"
      sha256 "b94985ff81b1af18ef3ba817f33d5c386d2d98df789206951cae0403cf5e6902"
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
