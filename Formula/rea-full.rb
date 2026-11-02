# rea-full is the "everything Homebrew can install" variant of Formula/rea.rb:
# it depends on REA and on every optional analysis integration Homebrew carries
# as a formula, so one `brew install` produces a REA whose `rea doctor` finds
# them.
#
# Where each provider comes from:
#
#   rizin       rizin        REA_RIZIN_COMMAND (debugger and Cutter bridge)
#   gdb         gdb          REA_GDB_COMMAND
#   apktool     apktool      REA_APKTOOL_COMMAND
#   binwalk     binwalk 3.1  REA_BINWALK_COMMAND
#   tshark      wireshark    REA_TSHARK_COMMAND, plus capinfos
#   WABT        wabt 1.0.42  REA_WABT_BIN_DIRECTORY (absolute directory)
#   sigrok      sigrok-cli   REA_SIGROK_COMMAND
#
# objdump needs no dependency: the Command Line Tools' /usr/bin/objdump is the
# provider REA looks for by default. GNU binutils would not do, because it is
# keg-only and prefixes its tools (`gobjdump`), so REA's `objdump` provider
# would never see it.
#
# The rest cannot be formula dependencies: Hopper, Cutter and mitmproxy are
# casks, and unblob, IDA and JEB are not packaged in Homebrew at all. The
# caveats list the cask commands and the settings for the rest.
#
# The source below is Formula/rea.rb's own tarball, used only for its
# documentation; `scripts/bump/rea.py` re-pins both formulae from one release.
class ReaFull < Formula
  desc "REA with every optional integration Homebrew can install as a formula"
  homepage "https://github.com/morluto/rea"
  url "https://registry.npmjs.org/rea-agents/-/rea-agents-6.8.0.tgz"
  sha256 "8d542ec76a9cb350584b60a6c9c088706ff812d5bb5b094c20c95b6dc25698bb"
  license "MIT"

  depends_on "apktool"
  depends_on "binwalk"
  # Named with the tap for the same reason rea.rb names ghidra@12.1: another
  # tap may ship a formula called `rea`, and an unqualified dependency would
  # then refuse to resolve.
  depends_on "fmu/tap/rea"
  depends_on "gdb"
  depends_on "rizin"
  depends_on "sigrok-cli"
  depends_on "wabt"
  depends_on "wireshark"

  def install
    prefix.install_metafiles
  end

  def caveats
    <<~EOS
      This formula adds every REA integration Homebrew packages as a formula.
      The remaining ones are casks, which formulae cannot depend on:

        brew install --cask hopper-disassembler   # Hopper provider
        brew install --cask cutter                # Cutter, rizin's GUI
        brew install --cask mitmproxy             # mitmdump

      unblob, IDA and JEB are not in Homebrew; `rea doctor --json` names the
      setting for each integration it cannot find. WABT wants an absolute
      directory rather than a PATH entry:

        export REA_WABT_BIN_DIRECTORY="$(brew --prefix wabt)/bin"

      REA's engine pins and the GHIDRA_INSTALL_DIR, REA_KUNA_COMMAND,
      REA_JADX_MCP_JAR and JAVA_HOME settings are documented by `brew info rea`.
    EOS
  end

  test do
    assert_match version.to_s, shell_output("#{formula_opt_bin("rea")}/rea --version")

    assert_path_exists formula_opt_bin("rizin")/"rizin"
    assert_path_exists formula_opt_bin("gdb")/"gdb"
    assert_path_exists formula_opt_bin("apktool")/"apktool"
    assert_path_exists formula_opt_bin("binwalk")/"binwalk"
    assert_path_exists formula_opt_bin("wabt")/"wasm2wat"
    assert_path_exists formula_opt_bin("sigrok-cli")/"sigrok-cli"
    assert_path_exists formula_opt_bin("wireshark")/"tshark"
    assert_path_exists formula_opt_bin("wireshark")/"capinfos"
  end
end
