# rea-full is the "everything Homebrew can install" variant of Formula/rea.rb:
# it depends on REA and on every optional analysis integration Homebrew carries
# as a formula, and it installs the `rea` and `rea-agents` launchers that supply
# the settings for all of them, so one `brew install` produces a REA that needs
# no shell profile.
#
# Where each provider comes from:
#
#   rizin       rizin        REA_RIZIN_COMMAND (debugger and Cutter bridge)
#   gdb         gdb          REA_GDB_COMMAND
#   apktool     apktool      REA_APKTOOL_COMMAND
#   binwalk     binwalk 3.1  REA_BINWALK_COMMAND
#   tshark      wireshark    REA_TSHARK_COMMAND and REA_CAPINFOS_COMMAND
#   unblob      unblob       REA_UNBLOB_COMMAND (firmware extraction)
#   WABT        wabt 1.0.42  REA_WABT_BIN_DIRECTORY (absolute directory)
#   sigrok      sigrok-cli   REA_SIGROK_COMMAND
#
# The launcher also points REA at the pinned engines of the rea keg it depends
# on (`ghidra@12.1`, `kuna@1.833`, `jadx-headless-mcp@0.7.1`) and at the
# openjdk@21 they are verified with. `brew info rea` documents the same
# settings for the unconfigured CLI.
#
# `rea` and `rea-full` both provide `bin/rea` and `bin/rea-agents`: they are
# alternatives, not additions. Homebrew treats a `-full` sibling as one link
# family, so installing rea-full on top of rea replaces the plain commands with
# these launchers and reports the overwritten links, and installing rea again
# takes them back. Uninstalling rea-full leaves rea installed but unlinked:
#
#   brew unlink rea && brew link rea
#
# restores the plain CLI (`brew install fmu/tap/rea` first, if Homebrew's
# autoremove removed the dependency keg together with this formula).
#
# objdump needs no setting: the Command Line Tools' /usr/bin/objdump is the
# provider REA looks for by default. GNU binutils would not do, because it is
# keg-only and prefixes its tools (`gobjdump`), so REA's `objdump` provider
# would never see it.
#
# The rest cannot be formula dependencies: Hopper, Cutter and mitmproxy are
# casks, and IDA and JEB are not packaged in Homebrew at all. The caveats list
# the cask commands and the settings for the rest.
#
# The source below is Formula/rea.rb's own tarball, used for its version,
# documentation and package manifest; `scripts/bump/rea.py` re-pins both
# formulae from one release.
class ReaFull < Formula
  desc "REA with every optional integration Homebrew can install as a formula"
  homepage "https://github.com/morluto/rea"
  url "https://registry.npmjs.org/rea-agents/-/rea-agents-6.8.0.tgz"
  sha256 "8d542ec76a9cb350584b60a6c9c088706ff812d5bb5b094c20c95b6dc25698bb"
  license "MIT"
  # Kegs installed before the launcher change are still the old metapackage
  # and have no bin/: without this revision `brew upgrade` reports 6.8.0 as
  # current and those installs keep running the unconfigured CLI (AGENTS.md).
  revision 1

  depends_on "apktool"
  depends_on "binwalk"
  # Named with the tap for the same reason rea.rb names ghidra@12.1: another
  # tap may ship a formula called `rea`, and an unqualified dependency would
  # then refuse to resolve.
  depends_on "fmu/tap/rea"
  depends_on "gdb"
  depends_on "rizin"
  depends_on "sigrok-cli"
  depends_on "unblob"
  depends_on "wabt"
  depends_on "wireshark"

  def install
    prefix.install_metafiles
    # Keep the npm package manifest: it names the release the launcher wraps.
    prefix.install "package.json"

    # Every setting REA reads from the environment for the engines it verifies
    # and the integrations this formula depends on. The absolute keg paths keep
    # the launcher correct for an agent client that never loaded a shell
    # profile.
    settings = {
      # The engine pins `scripts/bump/rea.py` keeps in step with REA.
      "GHIDRA_INSTALL_DIR"     => formula_opt_libexec("ghidra@12.1"),
      "REA_KUNA_COMMAND"       => formula_opt_bin("kuna@1.833")/"kuna",
      "REA_JADX_MCP_JAR"       => formula_opt_libexec("jadx-headless-mcp@0.7.1")/"jadx-headless-mcp.jar",
      # The integrations this formula depends on.
      "REA_APKTOOL_COMMAND"    => formula_opt_bin("apktool")/"apktool",
      "REA_BINWALK_COMMAND"    => formula_opt_bin("binwalk")/"binwalk",
      "REA_CAPINFOS_COMMAND"   => formula_opt_bin("wireshark")/"capinfos",
      "REA_GDB_COMMAND"        => formula_opt_bin("gdb")/"gdb",
      "REA_RIZIN_COMMAND"      => formula_opt_bin("rizin")/"rizin",
      "REA_SIGROK_COMMAND"     => formula_opt_bin("sigrok-cli")/"sigrok-cli",
      "REA_TSHARK_COMMAND"     => formula_opt_bin("wireshark")/"tshark",
      "REA_UNBLOB_COMMAND"     => formula_opt_bin("unblob")/"unblob",
      "REA_WABT_BIN_DIRECTORY" => formula_opt_bin("wabt"),
    }
    # The Ghidra bridge is verified with the openjdk@21 that ghidra@12.1
    # brings, and the JADX bridge needs a full JDK, which that release is.
    java_home = Language::Java.java_home("21")
    settings["JAVA_HOME"] = java_home if java_home

    defaults = settings.map do |name, value|
      %Q(  ["#{name}", "#{value}"],)
    end.join("\n")

    # A Node launcher rather than a shell wrapper: `rea setup` records the path
    # REA was invoked through in the agent registrations it writes, so a shell
    # wrapper would register the inner CLI and the configured clients would
    # lose these settings. Loading the CLI in this process keeps
    # `process.argv[1]` pointing at the launcher.
    launcher = <<~JS
      #!#{formula_opt_bin("node")}/node
      // Generated by the fmu/tap rea-full formula. The caller's environment
      // wins: a setting that is already present is never overridden.
      //
      // Dynamic imports keep this file loadable whether Node classifies the
      // extensionless script as CommonJS or as ESM (the package next to it
      // declares "type": "module").
      const defaults = [
      __REA_DEFAULTS__
      ];
      for (const [name, value] of defaults) {
        if (process.env[name] === undefined) process.env[name] = value;
      }
      Promise.all([import("node:fs"), import("node:url")])
        .then(([fs, url]) => {
          // Resolve the rea keg at launch, so `brew upgrade rea` is picked up.
          const cli = fs.realpathSync("#{formula_opt_libexec("rea")}/bin/rea");
          return import(url.pathToFileURL(cli).href);
        })
        .then(undefined, (error) => {
          console.error(error);
          process.exitCode = 1;
        });
    JS
    # The defaults are indented for the generated file; insert them after the
    # heredoc dedented so they keep that indentation.
    launcher = launcher.sub("__REA_DEFAULTS__", defaults)

    # The npm package exposes `rea` and the legacy `rea-agents`; the launcher
    # claims both names so neither can run the unconfigured CLI.
    %w[rea rea-agents].each do |command|
      (bin/command).write launcher
      chmod 0555, bin/command
    end
  end

  def caveats
    <<~EOS
      `rea` and the package's `rea-agents` alias are installed as launchers that
      supply REA's engine and integration settings, so nothing needs to be
      exported. `rea doctor --json` reports the pinned Ghidra, Kuna and JADX
      engines, and `rea setup` registers the launcher itself, so the agent
      clients it configures inherit the same settings. An REA_* variable that
      is already exported overrides the launcher's default.

      This formula is an alternative to the plain `rea` formula, not an
      addition: both provide `bin/rea` and `bin/rea-agents`, and installing one
      after the other replaces those commands (Homebrew reports the overwritten
      links). If this formula is removed and the plain, unconfigured CLI is
      wanted back:

        brew unlink rea && brew link rea

      when Homebrew's autoremove did not also remove the `rea` dependency keg;
      `brew install fmu/tap/rea` reinstalls it otherwise.

      The remaining integrations are casks, which formulae cannot depend on:

        brew install --cask hopper-disassembler   # Hopper provider
        brew install --cask cutter                # Cutter, rizin's GUI
        brew install --cask mitmproxy             # mitmdump

      IDA and JEB are not in Homebrew. `rea doctor --json` inspects the engines
      and agent registrations only; the optional integrations are wired by the
      launcher and report themselves when a tool runs.
    EOS
  end

  test do
    assert_match version.to_s, shell_output("#{bin}/rea --version")
    assert_match version.to_s, shell_output("#{bin}/rea-agents --version")

    # The launcher is generated; a syntax error would otherwise only surface on
    # the next REA call.
    shell_output("#{formula_opt_bin("node")}/node --check #{bin}/rea")

    launcher = (bin/"rea").read
    %w[
      GHIDRA_INSTALL_DIR REA_KUNA_COMMAND REA_JADX_MCP_JAR
      REA_APKTOOL_COMMAND REA_BINWALK_COMMAND REA_CAPINFOS_COMMAND
      REA_GDB_COMMAND REA_RIZIN_COMMAND REA_SIGROK_COMMAND
      REA_TSHARK_COMMAND REA_UNBLOB_COMMAND REA_WABT_BIN_DIRECTORY JAVA_HOME
    ].each do |setting|
      assert_includes launcher, setting
    end

    assert_path_exists formula_opt_bin("rizin")/"rizin"
    assert_path_exists formula_opt_bin("gdb")/"gdb"
    assert_path_exists formula_opt_bin("apktool")/"apktool"
    assert_path_exists formula_opt_bin("binwalk")/"binwalk"
    assert_path_exists formula_opt_bin("wabt")/"wasm2wat"
    assert_path_exists formula_opt_bin("sigrok-cli")/"sigrok-cli"
    assert_path_exists formula_opt_bin("wireshark")/"tshark"
    assert_path_exists formula_opt_bin("wireshark")/"capinfos"
    assert_path_exists formula_opt_bin("unblob")/"unblob"
  end
end
