# The headless half of the DesignCraft release. The app is the `designcraft`
# cask in homebrew-cask: both are built from one upstream tag, so this formula
# is pinned to the release the app is on when it is added (0.15.2) and the
# scheduled bump follows the same GitHub release stream the cask tracks.
#
# It is packaged like homebrew-core's photocraft-cli formula: build the CLI from
# the tagged source with Rust, prefetching crates in `fetch` so the install
# itself runs without network access. `run`, `script`, `commands`, `describe`,
# `mcp`, `validate-pdf`, `perf` and `bench` are the same engine the app uses;
# `run --sample --export page.png` exercises layout and rendering in `brew test`
# without starting the desktop app.
class DesigncraftCli < Formula
  desc "Headless DesignCraft engine to lay out, edit and export documents"
  homepage "https://getartcraft.com/apps/designcraft"
  url "https://github.com/storytold/designcraft/archive/refs/tags/v0.15.2.tar.gz"
  sha256 "d1baa1292ff2543ae7ce66fe80c63d45908e95e98b46f2915522d4a9d312b873"
  license any_of: ["MIT", "Apache-2.0"]
  head "https://github.com/storytold/designcraft.git", branch: "main"

  livecheck do
    url :stable
    strategy :github_latest
  end

  depends_on "rust" => :build

  deny_network_access!

  def fetch
    system "cargo", "fetch", *std_cargo_fetch_args
  end

  def install
    system "cargo", "install", *std_cargo_args(path: "apps/designcraft-cli")
  end

  test do
    assert_match version.to_s, shell_output("#{bin}/designcraft-cli --version")
    assert_match "frame.create", shell_output("#{bin}/designcraft-cli commands frame.create")

    # The sample magazine is compiled into the engine, so this lays out and
    # renders one page without needing the app or a document on disk.
    system bin/"designcraft-cli", "run", "--sample", "--export", "page.png"
    assert_equal "\x89PNG".b, (testpath/"page.png").binread(4)
    assert_operator (testpath/"page.png").size, :>, 1000
  end
end
