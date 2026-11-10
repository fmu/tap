# DeArrow's free Safari channel follows the same build-it-yourself recipe as
# SponsorBlock's: take the Safari web extension attached to a release, wrap it in
# a macOS app, build that app, then tell Safari to load the unsigned build.
# Xcode's `safari-web-extension-packager` cannot read the extension from inside
# Homebrew's build sandbox, so this formula uses the other source upstream
# publishes: the generated Xcode project of the App Store app
# (ajayyy/DeArrowSafari), which references the web extension's `dist` directory
# and only needs the release's files put in place and xcodebuild.
#
# The asset is the fully built Safari web extension: upstream's release workflow
# runs webpack and zips `dist`, so nothing is compiled from JavaScript here and
# no npm is needed. Xcode is required because the generated project builds with
# xcodebuild, which ships only with Xcode and not with the Command Line Tools;
# the build is therefore never bottled.
#
# The resulting app is ad-hoc signed. Homebrew does not quarantine files it
# installs, but Safari loads an extension from a signed app only, or from an
# ad-hoc/unsigned development build after "Allow unsigned extensions" is turned
# on for that Safari session; the caveats register the app extension and spell
# out the Safari-side steps.
class SafariExtDearrow < Formula
  desc "DeArrow Safari web extension for descriptive YouTube titles and thumbnails"
  homepage "https://github.com/ajayyy/DeArrow"
  url "https://github.com/ajayyy/DeArrow/releases/download/2.3.10/SafariExtension.zip"
  sha256 "ae06461caca115e93ed0e9bb958414635736009f841f26f2812fd942990b5e33"
  license "GPL-3.0-or-later"

  livecheck do
    url :stable
    strategy :github_latest
  end

  depends_on xcode: :build
  depends_on :macos

  # Upstream's generated Xcode project for the App Store app. It is static glue
  # around the webpack build, not a release artifact, so it is pinned by commit
  # and moved by hand when upstream regenerates it for a new Xcode.
  resource "wrapper" do
    url "https://github.com/ajayyy/DeArrowSafari/archive/96cb6e0ed7024351f94fc205f70501813545c8ae.tar.gz"
    sha256 "893bde4900ce0ad3404df2083c84a5471f7ec5665f918868efb18f1970923d2f"
  end

  def install
    archive_root = "DeArrowSafari-96cb6e0ed7024351f94fc205f70501813545c8ae"
    system "tar", "-xzf", resource("wrapper").cached_download, "-C", buildpath
    wrapper = buildpath/archive_root
    odie "the wrapper archive did not extract to #{wrapper}" unless wrapper.directory?

    # The project references ../../../DeArrow/dist, relative to its extension
    # group; the release zip holds exactly the dist contents at its root.
    extension = wrapper/"DeArrow/dist"
    extension.mkpath
    system "unzip", "-q", cached_download, "-d", extension

    project = wrapper/"DeArrowSafari/DeArrow"
    pbxproj = project/"DeArrow.xcodeproj/project.pbxproj"
    odie "the wrapper archive did not contain #{pbxproj}" unless pbxproj.exist?

    # The committed project is the App Store app: replace upstream's bundle
    # identifiers and team with this formula's local identity before building.
    inreplace pbxproj do |s|
      s.gsub! "app.ajay.dearrow.extension", "dev.fmu.safari-ext-dearrow.Extension"
      s.gsub! "app.ajay.dearrow", "dev.fmu.safari-ext-dearrow"
      s.gsub! 'CODE_SIGN_IDENTITY = "Apple Development";', 'CODE_SIGN_IDENTITY = "-";'
      s.gsub! "CODE_SIGN_STYLE = Automatic;", "CODE_SIGN_STYLE = Manual;"
      s.gsub! "DEVELOPMENT_TEAM = 2PCQH7P6MB;", 'DEVELOPMENT_TEAM = "";'
    end

    # No development team: "Sign to Run Locally" is an ad-hoc signature, which
    # needs no certificate and is what Safari calls an unsigned extension.
    xcodebuild "build",
               "-project", pbxproj.dirname.to_s,
               "-target", "DeArrow (macOS)",
               "-configuration", "Release",
               "SYMROOT=#{buildpath/"build"}",
               "OBJROOT=#{buildpath/"build/obj"}",
               "MARKETING_VERSION=#{version}",
               "CURRENT_PROJECT_VERSION=#{version}",
               "CODE_SIGNING_REQUIRED=NO",
               "AD_HOC_CODE_SIGNING_ALLOWED=YES",
               "DEVELOPMENT_TEAM=",
               "ENABLE_HARDENED_RUNTIME=NO",
               "ONLY_ACTIVE_ARCH=YES"

    app = buildpath/"build/Release/DeArrow.app"
    odie "xcodebuild did not produce #{app}" unless app.directory?
    odie "#{app} does not contain the Safari web extension" if (app/"Contents/PlugIns").glob("*.appex").none?

    prefix.install app
  end

  def caveats
    appex = opt_prefix/"DeArrow.app/Contents/PlugIns/DeArrow Extension.appex"
    <<~EOS
      Safari only loads this extension from a signed app or, for this ad-hoc
      signed development build, after you allow unsigned extensions for the
      current Safari session. Register it with PlugInKit first (opening the app
      once also registers it):

        pluginkit -a "#{appex}"

      Check that Safari can see it:

        pluginkit -mAvvv -p com.apple.Safari.web-extension

      Then in Safari turn on Settings > Advanced > "Show features for web
      developers", open Settings > Developer and turn on "Allow unsigned
      extensions" (Touch ID or password; Safari clears this when it quits), and
      enable "DeArrow for YouTube" under Settings > Extensions.

      There is deliberately no shell switch for the unsigned-extension
      permission: it is a per-session authorisation, not a preference. On macOS
      27 Safari stores the "Show features for web developers" switch in a
      preference a shell can reveal (quit Safari first):

        defaults write com.apple.Safari.SandboxBroker ShowDevelopMenu -bool true

      After `brew upgrade`, register the app extension again (the command above
      uses the opt prefix, which follows the new keg).
    EOS
  end

  test do
    app = prefix/"DeArrow.app"
    appex = app/"Contents/PlugIns/DeArrow Extension.appex"
    assert_path_exists app/"Contents/Info.plist"
    assert_path_exists appex/"Contents/Info.plist"
    assert_equal version.to_s,
                 shell_output("/usr/bin/plutil -extract CFBundleShortVersionString raw " \
                              "'#{app}/Contents/Info.plist'").strip
    assert_equal "com.apple.Safari.web-extension",
                 shell_output("/usr/bin/plutil -extract NSExtension.NSExtensionPointIdentifier raw " \
                              "'#{appex}/Contents/Info.plist'").strip
    manifest = JSON.parse((appex/"Contents/Resources/manifest.json").read)
    assert_equal version.to_s, manifest["version"]
    assert_match "Signature=adhoc", shell_output("/usr/bin/codesign -dv '#{app}' 2>&1")
  end
end
