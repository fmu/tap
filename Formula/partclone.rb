# partclone backs up and restores the used blocks of a partition by using the
# filesystem's own library. unblob drives `partclone.restore` to unpack partclone
# images; that tool is filesystem-independent (it replays the image's used-block
# bitmap), so this formula builds the generic tools only. The filesystem-specific
# ones (partclone.extfs, partclone.ntfs, ...) need libraries macOS does not have.
#
# Upstream targets Linux: the patch guards linux/fs.h and mntent.h, uses
# getmntinfo() for the mount check, maps the Linux-only O_LARGEFILE/O_DIRECT
# flags to no-ops, and drops the Linux-only ntfsfixboot helper.
class Partclone < Formula
  desc "Utilities to back up and restore the used blocks of partitions"
  homepage "https://partclone.org/"
  url "https://github.com/Thomas-Tsai/partclone/archive/refs/tags/0.3.52.tar.gz"
  sha256 "15fcfafb42fea1fdbc9a022b2dc8cc49f60d49fee969b41ef3d05d944471dc12"
  license "GPL-2.0-or-later"

  livecheck do
    url :stable
    strategy :github_latest
    regex(/^v?(\d+(?:\.\d+)+)$/i)
  end

  depends_on "autoconf" => :build
  depends_on "automake" => :build
  depends_on "gettext" => :build
  depends_on "libtool" => :build
  depends_on "pkg-config" => :build
  depends_on "openssl@3"
  depends_on "zstd"

  patch do
    file "Patches/partclone-darwin.patch"
  end

  def install
    ENV["PKG_CONFIG"] = formula_opt_bin("pkg-config")/"pkg-config"
    ENV.prepend_path "PKG_CONFIG_PATH", formula_opt_lib("openssl@3")/"pkgconfig"
    ENV.prepend_path "PKG_CONFIG_PATH", formula_opt_lib("zstd")/"pkgconfig"
    ENV.prepend_path "ACLOCAL_PATH", formula_opt_prefix("gettext")/"share/aclocal"
    ENV.prepend_path "ACLOCAL_PATH", formula_opt_prefix("pkg-config")/"share/aclocal"
    ENV.prepend "CPPFLAGS", "-I#{formula_opt_include("openssl@3")} -I#{formula_opt_include("zstd")}"

    system "./autogen"
    system "./configure", "--prefix=#{prefix}",
           "--disable-nls", "--disable-xxhash", "--disable-dependency-tracking"
    system "make"
    sbin.install "src/partclone.info", "src/partclone.dd", "src/partclone.restore",
                 "src/partclone.chkimg", "src/partclone.imager"
  end

  test do
    assert_match version.to_s, shell_output("#{sbin}/partclone.restore --version")
  end
end
