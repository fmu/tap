# Ghidra 12.1.4, pinned.
#
# Ghidra extensions are compiled against one exact Ghidra version, and Ghidra's
# extension loader does not reject a mismatch at startup, so an API move only
# shows up later as a NoClassDefFoundError inside the affected tool. Homebrew
# core has moved on to 12.2 (which moved SleighLanguageDescription out of
# ghidra.program.model.lang), so this keg keeps 12.1.4 installable next to it
# for the tooling that is built against that release.
#
# This is the one package in the tap that the scheduled upstream bump does not
# touch: the pin is the point. Bump it by hand, together with whatever downstream
# build is pinned to the same Ghidra version. The official release archive
# supplies the Java tree as-is; only the macOS native components have to be
# compiled here (see `install`), so a build is a download, an unpack and a short
# Gradle run.
#
# The archive also carries one x86_64 Mach-O helper of its own,
# Features/FileFormats/data/sevenzipnativelibs/Mac-x86_64/lib7-Zip-JBinding.dylib.
# Homebrew's audit flags that as a non-native binary on Apple silicon, but it is
# upstream's 7-Zip binding rather than something this build produced, so
# audit_exceptions/mismatched_binary_allowlist.json records it; removing it would
# silently drop 7-Zip archive support.
class GhidraAT121 < Formula
  desc "Software reverse engineering framework (pinned for older extensions)"
  homepage "https://ghidra-sre.org/"
  url "https://github.com/NationalSecurityAgency/ghidra/releases/download/Ghidra_12.1.4_build/ghidra_12.1.4_PUBLIC_20260921.zip"
  version "12.1.4"
  sha256 "ddac49f903da9d5bac833e5cc79395098b9c33cfd3279be5f31bd00387d2d4db"
  license "Apache-2.0"
  revision 1

  keg_only :versioned_formula

  depends_on "openjdk@21"

  def install
    # Homebrew drops the single top-level directory for archives that have one;
    # older/newer unpack strategies differ, so accept both layouts.
    root = Pathname.glob("ghidra_*_PUBLIC").first
    tree = root || Pathname.pwd

    # The public release archive ships native components for Windows and Linux
    # only; on macOS they are user-built (GettingStarted.md, "Building Native
    # Components"). That is not optional here: the decompiler runs as a native
    # process, and the tooling this keg exists for drives it, so an unbuilt keg
    # can list symbols but cannot decompile anything. The release tree is complete and
    # carries the pinned Gradle wrapper, so the documented command is all that
    # is needed; the outputs go next to the release's Windows/Linux binaries,
    # where Ghidra looks after the build/ directory is removed.
    if OS.mac?
      platform = Hardware::CPU.arm? ? "mac_arm_64" : "mac_x86_64"
      ENV["JAVA_HOME"] = Language::Java.java_home("21")
      ENV.prepend_path "PATH", "#{ENV["JAVA_HOME"]}/bin"
      # Keep the wrapper download and its caches inside the build directory.
      ENV["GRADLE_USER_HOME"] = (buildpath/".gradle-home").to_s

      Dir.chdir((tree/"support"/"gradle").to_s) do
        system "bash", "./gradlew", "buildNatives", "--no-daemon"
      end

      Pathname.glob("#{tree}/**/build/os/#{platform}/*").each do |binary|
        module_dir = binary.dirname.parent.parent.parent
        (module_dir/"os"/platform).mkpath
        cp binary, module_dir/"os"/platform/binary.basename
      end
      rm_r(tree/"support"/"gradle"/".gradle")
      Pathname.glob("#{tree}/**/build").each { |dir| rm_r(dir) }
    end

    libexec.install Dir[root ? "#{root}/*" : "*"]

    (bin/"ghidraRun").write_env_script libexec/"ghidraRun",
                                       Language::Java.overridable_java_home_env("21")
    (bin/"pyghidraRun").write_env_script libexec/"support/pyghidraRun",
                                         Language::Java.overridable_java_home_env("21")
    (bin/"analyzeHeadless").write_env_script libexec/"support/analyzeHeadless",
                                             Language::Java.overridable_java_home_env("21")
  end

  test do
    assert_match "application.version=12.1.4",
                 (libexec/"Ghidra/application.properties").read

    if OS.mac?
      platform = Hardware::CPU.arm? ? "mac_arm_64" : "mac_x86_64"
      assert_predicate libexec/"Ghidra/Features/Decompiler/os"/platform/"decompile",
                       :executable?
    end
  end
end
