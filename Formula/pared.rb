# The CLI half of the Pared release; the app is Casks/pared-app.rb. Upstream
# keeps its own Formula/pared.rb, but that one builds from source and declares
# `depends_on xcode: ["27.0", :build]`. Every Pared artifact is already built and
# ad-hoc signed by upstream's release workflow, so the tap pins the released
# tarball instead.
#
# The layout matters. The executable loads its SwiftPM resource bundle through
# Bundle.module, which resolves the bundle next to the *executable path* and then
# falls back to the author's .build tree. Upstream's `bin.install_symlink` does not
# work: a symlink makes Bundle.main.bundleURL .../bin, so the lookup fails once the
# build tree is gone (verified with a SwiftPM probe). Install both beside each
# other in libexec and put an exec shim in bin, so the executable path stays
# libexec. The release is Apple silicon and macOS 27 only, like the app.
class Pared < Formula
  desc "Control Apple Intelligence features and remove downloaded models"
  homepage "https://github.com/4evy/pared"
  url "https://github.com/4evy/pared/releases/download/2.2.0/pared-macos-arm64.tar.gz"
  sha256 "14d6bba36cf00facc9b736348fe6a36b60f5b65a320b3eece66e41cb8d1613f9"
  license "MIT"

  livecheck do
    url :stable
    strategy :github_latest
  end

  depends_on arch: :arm64
  depends_on macos: :golden_gate

  def install
    libexec.install "pared", "pared_Pared.bundle"
    bin.write_exec_script libexec/"pared"
  end

  test do
    assert_path_exists libexec/"pared_Pared.bundle/Contents/Resources/catalog.json"
    # `features` renders the catalog from that bundle and touches no system state.
    assert_match "writingTools", shell_output("#{bin}/pared features")
  end
end
