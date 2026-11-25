# zed-remote-server is the headless half of Zed's remote development: the
# editor runs it on the remote host (over SSH or in a dev container) to serve
# file access, terminals, tasks, language servers and the debugger, while the
# UI keeps running locally.
#
# Upstream attaches one prebuilt binary per platform to every Zed release, so
# this formula installs that asset instead of building Zed's workspace. The
# asset is a bare gzip stream rather than a tarball, and what it unpacks to is
# its stored member name (`remote-server` on macOS, `remote_server` on Linux)
# rather than the asset name, so `install` takes the single file it produced.
#
# Zed normally provisions the server itself: it looks for a matching
# `~/.zed_server/zed-remote-server-<version>` on the host and downloads or
# uploads one when it is missing. This formula is for hosts where that is not
# wanted or not possible, and for pinning a known server version ahead of time.
#
# Upstream ships Linux and macOS builds only; the tap is POSIX-only, so there is
# no formula for the Windows assets. `scripts/bump/zed-remote-server.py` re-pins
# all four POSIX assets together, so the keg never mixes versions.
class ZedRemoteServer < Formula
  desc "Remote development server for the Zed editor"
  homepage "https://github.com/zed-industries/zed"
  license any_of: ["GPL-3.0-or-later", "Apache-2.0"]

  livecheck do
    url :stable
    strategy :github_latest
  end

  on_macos do
    on_arm do
      url "https://github.com/zed-industries/zed/releases/download/v1.30.2/zed-remote-server-macos-aarch64.gz"
      sha256 "693539699141aed4ede31b60a65f593398dbcb6e7ebc3033c0cbe320826bd6ff"
    end

    on_intel do
      url "https://github.com/zed-industries/zed/releases/download/v1.30.2/zed-remote-server-macos-x86_64.gz"
      sha256 "9f5074a5a3142a1fe89aa3298925ced4dc68c9426592694a76eae42352dbf2c0"
    end
  end

  on_linux do
    on_arm do
      url "https://github.com/zed-industries/zed/releases/download/v1.30.2/zed-remote-server-linux-aarch64.gz"
      sha256 "46b2bd1fe30743a9241a879ac4570b80fce1753210b53dc1c050b089bbf30547"
    end

    on_intel do
      url "https://github.com/zed-industries/zed/releases/download/v1.30.2/zed-remote-server-linux-x86_64.gz"
      sha256 "b755cd9c3a4354b66db77a3b5daa8b084965a3d3b391589f2737db2a68a1eadb"
    end
  end

  def install
    binary = Dir["*"].find { |path| File.file?(path) }
    odie "no binary in the unpacked zed-remote-server asset" if binary.nil?

    bin.install binary => "zed-remote-server"
  end

  def caveats
    <<~EOS
      This is the server binary Zed runs on a remote host, not the editor.
      Zed keeps its own copy per host and version under ~/.zed_server and
      installs one when the version you connect with has no matching binary
      there; this keg is the same upstream release asset, for provisioning a
      host ahead of time or for pinning a known server version.

      Zed finds a server binary under ~/.zed_server, so a Homebrew install
      does not replace the copy the editor manages. To inspect the release
      independently of Zed:

        zed-remote-server version

      The `run` and `proxy` subcommands are the protocol between the editor
      and the host, and the editor starts them with sockets and file paths of
      its own choosing.
    EOS
  end

  test do
    assert_equal version.to_s, shell_output("#{bin}/zed-remote-server version").strip
    assert_match "Usage: zed-remote-server", shell_output("#{bin}/zed-remote-server --help")
  end
end
