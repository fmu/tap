# Latest upstream release of the headless JADX MCP server. REA pins the release
# it verifies in Formula/jadx-headless-mcp@<release>.rb; this formula tracks
# upstream's latest release for standalone use and is bumped by
# `scripts/bump/jadx-headless-mcp.py`.
#
# REA launches the JAR itself through REA_JADX_MCP_JAR, so the formula installs it
# at a stable path instead of only exposing a wrapper. The wrapper is for using
# the same MCP server directly from another client.
class JadxHeadlessMcp < Formula
  desc "Headless MCP server for Android APK static analysis"
  homepage "https://github.com/1013503897/jadx-headless-mcp"
  url "https://github.com/1013503897/jadx-headless-mcp/releases/download/v0.8.0/jadx-headless-mcp-0.8.0-all.jar"
  sha256 "4b9a01c23845c123c217840182d2b5f2c26a7ca20dec3d08810b310fc80a2372"
  license "Apache-2.0"

  livecheck do
    url :stable
    strategy :github_latest
  end

  # A full JDK: REA's JADX bridge compiles against jdk.compiler.
  depends_on "openjdk"

  def install
    libexec.install "jadx-headless-mcp-#{version}-all.jar" => "jadx-headless-mcp.jar"

    (bin/"jadx-headless-mcp").write_env_script formula_opt_bin("openjdk")/"java",
                                               %Q(-jar "#{libexec}/jadx-headless-mcp.jar"),
                                               Language::Java.overridable_java_home_env
  end

  test do
    jar = libexec/"jadx-headless-mcp.jar"
    assert_path_exists jar

    # `java -jar` is a stdio MCP server that waits for a client, so inspect the
    # archive with the JDK's own tool instead of starting it.
    entries = shell_output("#{formula_opt_bin("openjdk")}/jar tf #{jar}")
    assert_match(/\.class$/, entries)
    assert_predicate bin/"jadx-headless-mcp", :executable?
  end
end
