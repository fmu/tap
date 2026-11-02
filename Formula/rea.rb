# REA is the package this tap exists for: one CLI and MCP server that drives
# native, managed, Android and JavaScript analysis engines and keeps their
# Evidence separate. This formula installs the published npm artifact — the same
# package the upstream installer and the agent plugins use — and links `rea`.
#
# REA verifies one exact release of each engine and reports every other release
# as unverified, so the engines are pinned together with REA rather than tracked
# individually:
#
#   jadx-headless-mcp 0.7.1   src/android/JadxRelease.ts (JADX_RELEASE.version)
#   kuna              1.833   src/kuna/KunaRelease.ts (KUNA_VERIFIED_VERSION)
#   ghidra            12.1.4  src/ghidra/GhidraReleasePolicy.ts
#                             (SUPPORTED_GHIDRA_VERSION, via ghidra@12.1)
#
# Do not bump those pins by hand: `scripts/bump/rea.py` reads them from the REA
# release tag, re-pins this formula, the `rea-full` metapackage and both engine
# formulae in one commit, and refuses to build a tap whose Ghidra pin no longer
# matches REA (a Ghidra move also needs a ghidra-mcp extension built for the new
# release, which no bump script can create). Hopper is a cask in homebrew-cask
# and is therefore an optional provider, not a dependency. Formula/rea-full.rb
# is the metapackage that adds every optional integration Homebrew packages.
#
# REA's remaining integrations are opt-in and discovered from PATH or a REA_*
# setting (rizin, gdb, objdump, apktool, binwalk, unblob, tshark, WABT, sigrok,
# mitmdump, IDA, JEB and Cutter). They are not dependencies: `rea doctor`
# reports them and REA runs without them. Nothing in REA links radare2 or
# capstone, so neither is declared here.
class Rea < Formula
  desc "Reverse engineer anything from your terminal or agent"
  homepage "https://github.com/morluto/rea"
  url "https://registry.npmjs.org/rea-agents/-/rea-agents-6.8.0.tgz"
  sha256 "8d542ec76a9cb350584b60a6c9c088706ff812d5bb5b094c20c95b6dc25698bb"
  license "MIT"

  # The analysis engines. ghidra@12.1 is keg-only and stays on the release REA
  # verifies; jadx-headless-mcp and kuna are pinned to the releases above.
  #
  # ghidra@12.1 is named with its tap because several taps may ship a formula
  # with that name (including this machine's fmu/config-nix), and an unqualified
  # dependency would then refuse to resolve.
  depends_on "fmu/tap/ghidra@12.1"
  depends_on "jadx-headless-mcp"
  depends_on "kuna"

  # REA itself runs on Node (engines: ^22.23.4 || ^24.22.1 || >=26.12.1) and
  # spawns the Ghidra and JADX bridges as Java processes.
  depends_on "node"
  depends_on "openjdk"

  def install
    # `std_npm_args` repacks the published tarball (dropping its prepare/prepack
    # scripts) and installs it global-style into libexec with its runtime
    # dependencies, which is why the CLI keeps its bundled `dist/` and `skills/`.
    system "npm", "install", *std_npm_args
    bin.install_symlink libexec.glob("bin/*")
  end

  def caveats
    <<~EOS
      REA finds its engines through environment variables. Point them at the
      kegs this formula installed, then run `rea setup` to register your agent
      clients; setup copies the detected values into the registrations it writes,
      so GUI clients inherit them:

        export GHIDRA_INSTALL_DIR="#{formula_opt_libexec("ghidra@12.1")}"
        export REA_KUNA_COMMAND="#{formula_opt_bin("kuna")}/kuna"
        export REA_JADX_MCP_JAR="#{formula_opt_libexec("jadx-headless-mcp")}/jadx-headless-mcp.jar"

      `rea doctor --json` reports every integration and what is still missing.

      Java: ghidra@12.1 brings the openjdk@21 that REA's Ghidra bridge is
      verified with, while openjdk (latest) is installed for the JADX bridge.
      REA selects a JDK from JAVA_HOME, then PATH, then Homebrew's `opt/openjdk`;
      if doctor complains about the Ghidra JDK, export JAVA_HOME as

        export JAVA_HOME="$(brew --prefix openjdk@21)/libexec/openjdk.jdk/Contents/Home"

      and re-run `rea setup`.

      Hopper is an optional provider and is not part of this dependency set,
      because Hopper ships as a cask:

        brew install --cask hopper-disassembler

      Complete Hopper's demo or licence dialog once in the same login session
      before REA launches it.

      Android analysis needs a full JDK with jdk.compiler (openjdk provides it)
      and the jar above. Ghidra analysis needs the native decompiler, which the
      ghidra@12.1 formula compiles for this host.

      REA's other integrations are optional and read from PATH or their REA_*
      setting, so install only what you use. Rizin (the debugger/Cutter bridge)
      is the one this tap can provide:

        brew install rizin
        export REA_RIZIN_COMMAND="$(brew --prefix rizin)/bin/rizin"

      gdb, objdump, apktool, binwalk, tshark, WABT, sigrok and mitmdump follow
      the same pattern; `rea doctor --json` lists each one with its setting.
    EOS
  end

  test do
    assert_match version.to_s, shell_output("#{bin}/rea --version")

    # The engines are pinned together with REA: a different release is reported
    # as unverified, so assert the exact set scripts/bump/rea.py writes.
    assert_match "kuna 1.833", shell_output("#{formula_opt_bin("kuna")}/kuna --version")
    assert_path_exists formula_opt_libexec("jadx-headless-mcp")/"jadx-headless-mcp.jar"
    assert_path_exists formula_opt_libexec("ghidra@12.1")/"Ghidra/application.properties"
  end
end
