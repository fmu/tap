# jadx-headless-mcp 0.7.1 is the release REA 6.8.0 verifies
# (src/android/JadxRelease.ts, JADX_RELEASE); REA reports every other JAR as
# unverified, so the pin is the point even though upstream has moved on to 0.8.0.
# `scripts/bump/rea.py` re-pins this formula together with REA.
#
# REA launches the JAR itself through REA_JADX_MCP_JAR, so the formula installs it
# at a stable path instead of only exposing a wrapper. The wrapper is for using
# the same MCP server directly from another client.
class JadxHeadlessMcp < Formula
  desc "Headless MCP server for Android APK static analysis"
  homepage "https://github.com/1013503897/jadx-headless-mcp"
  url "https://github.com/1013503897/jadx-headless-mcp/releases/download/v0.7.1/jadx-headless-mcp-0.7.1-all.jar"
  sha256 "6e5eacf500b64292bfb73c49797c1958f6ee44646e43e868039ae7feb573ff75"
  license "Apache-2.0"

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
