# sasquatch is ONEKEY's fork of squashfs-tools, extended with the vendor
# SquashFS variants that device firmware uses; unblob drives it for SquashFS
# extraction, including a `sasquatch-v4be` name for big-endian v4 images. It is
# not in Homebrew, which is why this tap packages it.
#
# The fork still assumes Linux: it includes <sys/sysinfo.h>/<sys/sysmacros.h>,
# uses sigtimedwait()/sigwaitinfo() in the status thread, and calls the Linux
# l*xattr() wrappers. The patch guards the Linux-only headers, uses sysctl() for
# the processor count on Darwin, provides sigwait()-based equivalents, and adds
# the xattr wrappers from upstream squashfs-tools.
class Sasquatch < Formula
  desc "Squashfs extraction tool with extra vendor formats"
  homepage "https://github.com/onekey-sec/sasquatch"
  url "https://github.com/onekey-sec/sasquatch/archive/refs/tags/sasquatch-v4.5.1-6.tar.gz"
  version "4.5.1-6"
  sha256 "57f2b90852d1d43a90f0a228337dc66642da4842494b84ba1896f34765edfc47"
  license "GPL-2.0-or-later"

  livecheck do
    url :stable
    strategy :github_latest
    regex(/^sasquatch-v?(.+)$/i)
  end

  depends_on "lz4"
  depends_on "lzo"
  depends_on "xz"
  depends_on "zstd"

  patch do
    file "Patches/sasquatch-darwin.patch"
  end

  def install
    cflags = %w[lzo lz4 xz zstd].map { |dep| "-I#{formula_opt_include(dep)}" }.join(" ")
    ldflags = %w[lzo lz4 xz zstd].map { |dep| "-L#{formula_opt_lib(dep)}" }.join(" ")

    cd "squashfs-tools" do
      system "make", "EXTRA_CFLAGS=#{cflags}", "LDFLAGS=#{ldflags}"
      bin.install "sasquatch"
      # unblob invokes the same binary under both names (see its SquashFS
      # handler); upstream installs the second name the same way.
      bin.install "sasquatch" => "sasquatch-v4be"
    end
  end

  test do
    assert_match "4.5.1", shell_output("#{bin}/sasquatch -version")
    assert_path_exists bin/"sasquatch-v4be"
  end
end
