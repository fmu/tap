# partclone backs up and restores the used blocks of a partition by using the
# filesystem's own library. unblob drives `partclone.restore`, which is
# filesystem-independent (it replays the image's used-block bitmap), but the
# filesystem-specific tools (`partclone.extfs`, `.zfs`, `.exfat`, ...) are what
# create images. They are built here so dumps can be produced on macOS too.
#
# Only the backends that are self-contained or need libraries available on
# macOS are enabled: extfs (Homebrew e2fsprogs), fat, exfat, hfsp, apfs, minix,
# ntfs (the libntfs-3g formula from this tap) and the clean-room zfs parser
# (Homebrew lz4 + e2fsprogs' blkid/uuid). The remaining upstream backends need
# Linux-only libraries and a large port: xfs/btrfs/f2fs; reiserfs, reiser4, jfs,
# nilfs2, ufs and vmfs have no macOS libraries at all.
#
# Upstream targets Linux: the patch guards linux/fs.h, mntent.h, malloc.h,
# linux/types.h and byteswap/endian headers, adds a be*toh shim for Darwin,
# uses getmntinfo() for the mount check, maps the Linux-only O_LARGEFILE/O_DIRECT
# flags to no-ops, reads block-device sizes with DKIOCGETBLOCK* and drops the
# Linux-only ntfsfixboot helper.
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
  depends_on "e2fsprogs"
  depends_on "libntfs-3g"
  depends_on "lz4"
  depends_on "openssl@3"
  depends_on "zstd"

  patch do
    file "Patches/partclone-darwin.patch"
  end

  def install
    ENV["PKG_CONFIG"] = formula_opt_bin("pkg-config")/"pkg-config"
    ENV.prepend_path "PKG_CONFIG_PATH", formula_opt_lib("openssl@3")/"pkgconfig"
    ENV.prepend_path "PKG_CONFIG_PATH", formula_opt_lib("zstd")/"pkgconfig"
    ENV.prepend_path "PKG_CONFIG_PATH", formula_opt_lib("e2fsprogs")/"pkgconfig"
    ENV.prepend_path "PKG_CONFIG_PATH", formula_opt_lib("libntfs-3g")/"pkgconfig"
    ENV.prepend_path "PKG_CONFIG_PATH", formula_opt_lib("lz4")/"pkgconfig"
    ENV.prepend_path "ACLOCAL_PATH", formula_opt_prefix("gettext")/"share/aclocal"
    ENV.prepend_path "ACLOCAL_PATH", formula_opt_prefix("pkg-config")/"share/aclocal"
    ENV.prepend "CPPFLAGS", "-I#{formula_opt_include("openssl@3")} -I#{formula_opt_include("zstd")} " \
                            "-I#{formula_opt_include("e2fsprogs")} -I#{formula_opt_include("libntfs-3g")} " \
                            "-I#{formula_opt_include("lz4")}"
    ENV.prepend "LDFLAGS", "-L#{formula_opt_lib("e2fsprogs")} -L#{formula_opt_lib("libntfs-3g")} " \
                           "-L#{formula_opt_lib("lz4")}"

    system "./autogen"
    system "./configure", "--prefix=#{prefix}",
           "--disable-nls", "--disable-xxhash", "--disable-dependency-tracking",
           "--enable-extfs", "--enable-hfsp", "--enable-apfs", "--enable-fat",
           "--enable-exfat", "--enable-minix", "--enable-ntfs", "--enable-zfs"
    system "make"
    sbin.install "src/partclone.info", "src/partclone.dd", "src/partclone.restore",
                 "src/partclone.chkimg", "src/partclone.imager",
                 "src/partclone.extfs", "src/partclone.hfsp", "src/partclone.apfs",
                 "src/partclone.fat", "src/partclone.exfat", "src/partclone.minix",
                 "src/partclone.ntfs", "src/partclone.zfs"
    sbin.install_symlink "partclone.extfs" => "partclone.ext2"
    sbin.install_symlink "partclone.extfs" => "partclone.ext3"
    sbin.install_symlink "partclone.extfs" => "partclone.ext4"
    sbin.install_symlink "partclone.extfs" => "partclone.ext4dev"
    sbin.install_symlink "partclone.hfsp" => "partclone.hfs+"
    sbin.install_symlink "partclone.hfsp" => "partclone.hfsplus"
    sbin.install_symlink "partclone.fat" => "partclone.fat12"
    sbin.install_symlink "partclone.fat" => "partclone.fat16"
    sbin.install_symlink "partclone.fat" => "partclone.fat32"
    sbin.install_symlink "partclone.fat" => "partclone.vfat"
  end

  test do
    assert_match version.to_s, shell_output("#{sbin}/partclone.restore --version")

    # Round-trip a small image through the generic dumper: no root, no
    # filesystem image tooling, and it exercises exactly what unblob runs
    # (restore -W); chkimg verifies the header/bitmap/checksums in between.
    (testpath/"src.bin").binwrite Random.new(42).bytes(64 * 1024)
    system sbin/"partclone.imager", "-c", "-s", testpath/"src.bin",
           "-o", testpath/"img.pcl", "-L", testpath/"partclone.log"
    system sbin/"partclone.chkimg", "-s", testpath/"img.pcl", "-L", testpath/"partclone.log"
    system sbin/"partclone.restore", "-W", "-s", testpath/"img.pcl",
           "-o", testpath/"dst.bin", "-L", testpath/"partclone.log"
    assert_equal (testpath/"src.bin").binread, (testpath/"dst.bin").binread

    # The filesystem-specific dumpers are the reason the formula builds more
    # than restore, so at least check the main one is installed and runnable.
    assert_match version.to_s, shell_output("#{sbin}/partclone.extfs --version")
    assert_match version.to_s, shell_output("#{sbin}/partclone.ntfs --version")
    assert_match version.to_s, shell_output("#{sbin}/partclone.zfs --version")
  end
end
