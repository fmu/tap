# libntfs-3g is the userspace NTFS library from the ntfs-3g project. The
# ntfs-3g FUSE driver needs macFUSE, which is why Homebrew's ntfs-3g formula is
# Linux-only, but partition tools such as partclone only need the library to
# read a volume's allocated clusters. This formula builds the library and its
# headers alone: no FUSE driver, no ntfsprogs utilities, no crypto.
class Libntfs3g < Formula
  desc "Userspace NTFS library from the ntfs-3g project"
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
           "--disable-ntfs-3g", "--disable-mount-helper", "--disable-ntfsprogs",
           "--disable-mtab", "--disable-ldconfig", "--disable-crypto",
           "--without-hd", "--disable-dependency-tracking"
    system "make"
    system "make", "install"

    # Refer to the dylib through the stable opt path so dependents keep
    # resolving it after an upgrade replaces the versioned Cellar directory.
    lib.glob("libntfs-3g.*.dylib").each do |dylib|
      change_dylib_id dylib, (opt_lib/dylib.basename).to_s
    end
  end

  test do
    (testpath/"test.c").write <<~C
      #include <sys/stat.h>
      #include <stdarg.h>
      #include <time.h>
      #include <ntfs-3g/volume.h>

      int main(void)
      {
        ntfs_volume *vol = ntfs_mount("/nonexistent", NTFS_MNT_RDONLY);
        return vol == (ntfs_volume *)0 ? 0 : 1;
      }
    C
    system ENV.cc, "-I#{include}", testpath/"test.c", "-L#{lib}", "-lntfs-3g",
           "-o", testpath/"test"
    system testpath/"test"
  end
end
