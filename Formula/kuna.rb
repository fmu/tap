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
      url "https://github.com/Noelo-Lab/kuna/releases/download/v1.1002/kuna-v1.1002-macos-arm64.tar.gz"
      sha256 "bd50881f53c95b53396644ce9073e6bb2befae3a8a7a3dae62d96ca9f247b02a"
    end

    on_intel do
      url "https://github.com/Noelo-Lab/kuna/releases/download/v1.1002/kuna-v1.1002-macos-x86_64.tar.gz"
      sha256 "e8ce152d2230a6d61080bee0dc589b0629424a515e645a6037cd0473fab6c5d1"
    end
  end

  on_linux do
    on_intel do
      url "https://github.com/Noelo-Lab/kuna/releases/download/v1.1002/kuna-v1.1002-linux-x86_64.tar.gz"
      sha256 "248061bbd74464816d6b9b42f70cdf7ca760b80b124ac544f4aed3d554e069fe"
    end

    on_arm do
      url "https://github.com/Noelo-Lab/kuna/releases/download/v1.1002/kuna-v1.1002-linux-arm64.tar.gz"
      sha256 "9c259186e64673e9e1858a6a0415ace3e5ae8974076486c24053c71c715531c2"
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
