# iQualize is a system-wide parametric EQ: it taps system audio with Core Audio
# Taps and applies the curve before the audio reaches the output device, so it
# needs no virtual audio driver. The project is MIT-licensed, the release has a
# Developer ID signature and is notarized (`spctl -a -t install` accepts it), so
# unlike mornye and mpv-app in this tap the cask carries no Gatekeeper caveat. It
# lives here because homebrew-cask does not ship it, not because homebrew-cask
# rejected it.
#
# The app bundles its `iqualize` CLI at Contents/Resources/bin but installs it to
# /usr/local/bin itself (Settings > General > "Install Command Line Tool", one
# admin prompt), so this cask deliberately adds no `binary` stanza: that would
# put a Homebrew-owned copy in /opt/homebrew/bin and leave `brew upgrade`
# updating a different binary than the one the app installs.
cask "iqualize" do
  version "0.60.1"
  sha256 "7c54d461e1110c1b20cf00b18d51fd056978f0f1533fdd47aa4466e272d7d740"

  url "https://github.com/dariuscorvus/iqualize/releases/download/v#{version}/iQualize-#{version}.dmg"
  name "iQualize"
  desc "System-wide parametric EQ with a real-time spectrum analyzer"
  homepage "https://iqualize.app/"

  livecheck do
    url :url
    strategy :github_latest
  end

  # LC_BUILD_VERSION reports minos 14.0, but Core Audio Taps — the API that
  # replaces the virtual driver — only exist from macOS 14.2. There is no 14.2
  # symbol, so the Sonoma minimum is the closest the cask can express.
  depends_on macos: :sonoma

  app "iQualize.app"

  uninstall quit: "codes.darius.iqualize"

  # State is keyed by the codes.darius.iqualize bundle id. Presets, custom ones
  # included, live in the defaults domain rather than in a document, so trashing
  # the plist is what makes zap a real purge. "Application Support/iQualize"
  # holds only the control.sock the CLI talks to. "Start at Login" is an
  # SMAppService registration, which has no file a zap could name.
  zap trash: [
    "~/Library/Application Support/iQualize",
    "~/Library/Caches/codes.darius.iqualize",
    "~/Library/HTTPStorages/codes.darius.iqualize",
    "~/Library/Preferences/codes.darius.iqualize.plist",
    "~/Library/Saved Application State/codes.darius.iqualize.savedState",
  ]
end
