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
      url "https://github.com/Noelo-Lab/kuna/releases/download/v1.1006/kuna-v1.1006-macos-arm64.tar.gz"
      sha256 "21466b052d8349f1fdf71fc3bd9adace8db78fc6203f74f16c285ab18143f7a2"
    end

    on_intel do
      url "https://github.com/Noelo-Lab/kuna/releases/download/v1.1006/kuna-v1.1006-macos-x86_64.tar.gz"
      sha256 "84112467f474428b363824e2cbd070ef8f9481be08adbc7f6088379f042f3762"
    end
  end

  on_linux do
    on_intel do
      url "https://github.com/Noelo-Lab/kuna/releases/download/v1.1006/kuna-v1.1006-linux-x86_64.tar.gz"
      sha256 "581870a0de985d28d1b724c589f721b834bcc68147f302aab3e20c35eb44a0b9"
    end

    on_arm do
      url "https://github.com/Noelo-Lab/kuna/releases/download/v1.1006/kuna-v1.1006-linux-arm64.tar.gz"
      sha256 "bb58c0e8ed82c21ed5d8fa6728b7e29a21a89a4daf2d8123ee614b9d59f33e4b"
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
