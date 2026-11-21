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
      url "https://github.com/Noelo-Lab/kuna/releases/download/v1.1003/kuna-v1.1003-macos-arm64.tar.gz"
      sha256 "a35f339df026d87b60759849a934a549cb73dea6b76d9b8a104b25cff9b52bb9"
    end

    on_intel do
      url "https://github.com/Noelo-Lab/kuna/releases/download/v1.1003/kuna-v1.1003-macos-x86_64.tar.gz"
      sha256 "1f8492a28887cc9717a1312e4ede3460f6f30d443386a396dc04f077aa7cf364"
    end
  end

  on_linux do
    on_intel do
      url "https://github.com/Noelo-Lab/kuna/releases/download/v1.1003/kuna-v1.1003-linux-x86_64.tar.gz"
      sha256 "b30098c91780ecbc7a839e41ca4e2129e26557075741a387925771a25d06ba3d"
    end

    on_arm do
      url "https://github.com/Noelo-Lab/kuna/releases/download/v1.1003/kuna-v1.1003-linux-arm64.tar.gz"
      sha256 "28b99d7839ade2fc7cf9d019276338a9732ef323e9c0a9739b731bc477b26e8f"
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
