# ntfsprogs is the userspace utilities half of ntfs-3g (mkntfs, ntfsls,
# ntfscat, ntfscp, ntfsclone, ntfsresize, ...). They do not use the FUSE
# driver, so they build on macOS when the driver is disabled; this formula links
# libntfs-3g into the tools statically and installs no library, so it has no
# runtime dependency on the libntfs-3g formula.
class Ntfsprogs < Formula
  desc "User-space NTFS utilities (mkntfs, ntfsls, ntfscat, ntfsclone, ...)"
  homepage "https://www.tuxera.com/community/open-source-ntfs-3g/"
  url "https://github.com/tuxera/ntfs-3g/archive/refs/tags/2026.9.28.tar.gz"
  sha256 "8a75293f07bf40df5701d296de32a4cb0e46d6ae135abb4f41b438df9868a390"
  license all_of: ["GPL-2.0-or-later", "LGPL-2.0-or-later"]

  livecheck do
    url :stable
    strategy :github_latest
  end

  depends_on "autoconf" => :build
  depends_on "automake" => :build
  depends_on "libtool" => :build

  def install
    # Declare the aux dir explicitly: libtoolize otherwise guesses it by looking
    # for install-sh in parent directories, which can pick a stray one and then
    # fail to install ltmain.sh.
    inreplace "configure.ac", /^AM_INIT_AUTOMAKE\(\[\]\)$/,
              "AC_CONFIG_AUX_DIR([.])\nAM_INIT_AUTOMAKE([])"
    # autogen.sh runs autoreconf; Homebrew ships libtoolize as glibtoolize.
    ENV["LIBTOOLIZE"] = formula_opt_bin("libtool")/"glibtoolize"
    system "./autogen.sh"
    system "./configure", "--prefix=#{prefix}", "--exec-prefix=#{prefix}",
           "--disable-ntfs-3g", "--disable-mount-helper", "--disable-mtab",
           "--disable-ldconfig", "--disable-library", "--disable-crypto",
           "--without-hd", "--enable-ntfsprogs", "--enable-extras",
           "--disable-dependency-tracking"
    system "make"

    bin.install "ntfsprogs/ntfsfix", "ntfsprogs/ntfsinfo", "ntfsprogs/ntfscluster",
                "ntfsprogs/ntfsls", "ntfsprogs/ntfscat", "ntfsprogs/ntfscmp",
                "ntfsprogs/ntfswipe", "ntfsprogs/ntfstruncate", "ntfsprogs/ntfsrecover",
                "ntfsprogs/ntfsusermap", "ntfsprogs/ntfssecaudit"
    sbin.install "ntfsprogs/mkntfs", "ntfsprogs/ntfslabel", "ntfsprogs/ntfsundelete",
                 "ntfsprogs/ntfsresize", "ntfsprogs/ntfsclone", "ntfsprogs/ntfscp"
    man8.install "ntfsprogs/mkntfs.8", "ntfsprogs/ntfscat.8", "ntfsprogs/ntfsclone.8",
                 "ntfsprogs/ntfscluster.8", "ntfsprogs/ntfscmp.8", "ntfsprogs/ntfscp.8",
                 "ntfsprogs/ntfsfix.8", "ntfsprogs/ntfsinfo.8", "ntfsprogs/ntfslabel.8",
                 "ntfsprogs/ntfsls.8", "ntfsprogs/ntfsprogs.8", "ntfsprogs/ntfsresize.8",
                 "ntfsprogs/ntfsundelete.8", "ntfsprogs/ntfsrecover.8",
                 "ntfsprogs/ntfssecaudit.8", "ntfsprogs/ntfstruncate.8",
                 "ntfsprogs/ntfsusermap.8", "ntfsprogs/ntfswipe.8"
  end

  test do
    (testpath/"ntfs.img").open("wb") { |f| f.truncate(16 * 1024 * 1024) }
    (testpath/"hello.txt").write "hello from ntfsprogs\n"

    system sbin/"mkntfs", "--force", "--fast", "--label", "Homebrew", testpath/"ntfs.img"
    assert_match "Homebrew", shell_output("#{sbin}/ntfslabel #{testpath}/ntfs.img")

    system sbin/"ntfscp", testpath/"ntfs.img", testpath/"hello.txt", "/hello.txt"
    assert_equal "hello from ntfsprogs\n",
                 shell_output("#{bin}/ntfscat #{testpath}/ntfs.img /hello.txt")
    assert_match "hello.txt", shell_output("#{bin}/ntfsls #{testpath}/ntfs.img")

    system bin/"ntfsfix", "--no-action", testpath/"ntfs.img"
    system bin/"ntfsinfo", "-m", testpath/"ntfs.img"
  end
end
