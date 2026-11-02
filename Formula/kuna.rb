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
      url "https://github.com/Noelo-Lab/kuna/releases/download/v1.989/kuna-v1.989-macos-arm64.tar.gz"
      sha256 "4061b81c656ed4f2697e5669898f3d89e1c7355a57090afa765942ef455a704e"
    end

    on_intel do
      url "https://github.com/Noelo-Lab/kuna/releases/download/v1.989/kuna-v1.989-macos-x86_64.tar.gz"
      sha256 "e0b8848357fd414025d0199878d5856986f6f004396b2f8bb7f74e1f6eb1960c"
    end
  end

  on_linux do
    on_intel do
      url "https://github.com/Noelo-Lab/kuna/releases/download/v1.989/kuna-v1.989-linux-x86_64.tar.gz"
      sha256 "f935d848ba4b3f515479b9dbcbf749b170e64703ae0636f28b050e7368ab517f"
    end

    on_arm do
      url "https://github.com/Noelo-Lab/kuna/releases/download/v1.989/kuna-v1.989-linux-arm64.tar.gz"
      sha256 "b5f12a6751a02ddd7c245c4ebfde008542041d702c7438dc30e778ae6216c47e"
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
