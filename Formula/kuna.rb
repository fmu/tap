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
      url "https://github.com/Noelo-Lab/kuna/releases/download/v1.995/kuna-v1.995-macos-arm64.tar.gz"
      sha256 "a998bf6dd45360ab59a3959c79e51dde63edfa45968c4c24f6e1a7b4b88aa080"
    end

    on_intel do
      url "https://github.com/Noelo-Lab/kuna/releases/download/v1.995/kuna-v1.995-macos-x86_64.tar.gz"
      sha256 "d59dff5816eec61e01493ef1c78d583b87d590208e5f7418e44fe537a6f59980"
    end
  end

  on_linux do
    on_intel do
      url "https://github.com/Noelo-Lab/kuna/releases/download/v1.995/kuna-v1.995-linux-x86_64.tar.gz"
      sha256 "f506d8fcdfb3c9952f94dfd44d7b5d928cf966f4fb55f80a30ec708cabb8d075"
    end

    on_arm do
      url "https://github.com/Noelo-Lab/kuna/releases/download/v1.995/kuna-v1.995-linux-arm64.tar.gz"
      sha256 "e4c071192ecb477a2135ed681c59ef14e335bca8aaa790619bcf1bdae18ab7e1"
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
