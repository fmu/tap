# Kuna 1.833 is the release REA 6.8.0 verifies (src/kuna/KunaRelease.ts,
# KUNA_VERIFIED_VERSION); REA reports every other release as unverified, so the
# pin is the point even though upstream moves faster (1.987 at the time of
# writing). `scripts/bump/rea.py` re-pins this formula together with REA, never
# from Kuna's own release feed.
#
# The release is one self-contained executable per platform; it links only the
# system libraries, so there is nothing to compile and nothing else to depend on.
class Kuna < Formula
  desc "Agent-first decompiler for x86-64, AArch64 and ARM binaries"
  homepage "https://github.com/Noelo-Lab/kuna"
  license "Apache-2.0"

  on_macos do
    on_arm do
      url "https://github.com/Noelo-Lab/kuna/releases/download/v1.833/kuna-v1.833-macos-arm64.tar.gz"
      sha256 "6d5f2157bf7aef705c670b044a38f69574e184bf0ebd062f2a0d5e0545844c90"
    end

    on_intel do
      url "https://github.com/Noelo-Lab/kuna/releases/download/v1.833/kuna-v1.833-macos-x86_64.tar.gz"
      sha256 "6b1c45bc28c0b4281599ce757762b8bd4f6c13df94352e564aaa7dc980af2df0"
    end
  end

  on_linux do
    on_intel do
      url "https://github.com/Noelo-Lab/kuna/releases/download/v1.833/kuna-v1.833-linux-x86_64.tar.gz"
      sha256 "e9f047fb5a93925ede6d869df22c26c1c0ced90764ace7467ae90f880625d530"
    end

    on_arm do
      url "https://github.com/Noelo-Lab/kuna/releases/download/v1.833/kuna-v1.833-linux-arm64.tar.gz"
      sha256 "c1f7cd7cdb990cdf1149d2f595a56adf3a4afce052d014b2b6670adbfbcc71e5"
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
