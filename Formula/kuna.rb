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
      url "https://github.com/Noelo-Lab/kuna/releases/download/v1.996/kuna-v1.996-macos-arm64.tar.gz"
      sha256 "5e3c96f4db0c5cef30c0c235fbe4717a7839e22d08760219dcfbf0259de1e599"
    end

    on_intel do
      url "https://github.com/Noelo-Lab/kuna/releases/download/v1.996/kuna-v1.996-macos-x86_64.tar.gz"
      sha256 "11be312ed7ea708ca886ab0823220ba32b892d949f7da6aca4057badd0ad16f8"
    end
  end

  on_linux do
    on_intel do
      url "https://github.com/Noelo-Lab/kuna/releases/download/v1.996/kuna-v1.996-linux-x86_64.tar.gz"
      sha256 "3e612d42676d282e206f9adee8c74aff81c19832e766b8f85001919bdd5985b9"
    end

    on_arm do
      url "https://github.com/Noelo-Lab/kuna/releases/download/v1.996/kuna-v1.996-linux-arm64.tar.gz"
      sha256 "e020e7986b6a07bdb13d038d7ac0cf6b7117e67614a94fd6998ebaa60f471b35"
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
