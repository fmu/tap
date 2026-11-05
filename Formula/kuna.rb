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
      url "https://github.com/Noelo-Lab/kuna/releases/download/v1.991/kuna-v1.991-macos-arm64.tar.gz"
      sha256 "b4559c105a68acb81eada0629dc938d224f4696f670dff01f21584ba44ecea9b"
    end

    on_intel do
      url "https://github.com/Noelo-Lab/kuna/releases/download/v1.991/kuna-v1.991-macos-x86_64.tar.gz"
      sha256 "1bc060fdd2615a9fca7c6697f85d410924ad6061711fb7ed550514c8181c96ad"
    end
  end

  on_linux do
    on_intel do
      url "https://github.com/Noelo-Lab/kuna/releases/download/v1.991/kuna-v1.991-linux-x86_64.tar.gz"
      sha256 "3d4738fdbb9f8aad777519289171c9ba5abe6b73bc57d8f01e400a65f13ca16b"
    end

    on_arm do
      url "https://github.com/Noelo-Lab/kuna/releases/download/v1.991/kuna-v1.991-linux-arm64.tar.gz"
      sha256 "b1b615d711f9da8378d7548c7aeea955effb3af7d386f8eb6999159594066301"
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
