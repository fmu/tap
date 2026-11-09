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
      url "https://github.com/Noelo-Lab/kuna/releases/download/v1.994/kuna-v1.994-macos-arm64.tar.gz"
      sha256 "9dff8e2de5cc2afd359c57fddf4a868a57c66cfd9e22732d37bb4ed4e794a17a"
    end

    on_intel do
      url "https://github.com/Noelo-Lab/kuna/releases/download/v1.994/kuna-v1.994-macos-x86_64.tar.gz"
      sha256 "c027d616b005fa09c77783c332db2e3414de7a67dde2d93e73bb7adae0f8fab3"
    end
  end

  on_linux do
    on_intel do
      url "https://github.com/Noelo-Lab/kuna/releases/download/v1.994/kuna-v1.994-linux-x86_64.tar.gz"
      sha256 "cc8b329131376a510e1f7457eb3c38ff05372b4c455f5d4fa09f0bc4fed6c118"
    end

    on_arm do
      url "https://github.com/Noelo-Lab/kuna/releases/download/v1.994/kuna-v1.994-linux-arm64.tar.gz"
      sha256 "473c9885574540f340f0ab1a50ac8e7f18b244b4d2ee98156ebfc81a595077d8"
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
