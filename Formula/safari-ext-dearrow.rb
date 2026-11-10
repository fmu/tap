# DeArrow's free Safari channel is the same build-it-yourself recipe as
# SponsorBlock's: take the Safari web extension attached to a release, wrap it
# in a macOS app, build that app, then tell Safari to load the unsigned build.
# Xcode's `safari-web-extension-packager` cannot read the extension under
# Homebrew's build sandbox, and `xcodebuild` needs a fully installed Xcode: on a
# machine whose Xcode has not had its first-launch components installed it dies
# before building anything ("A required plugin failed to load" from
# IDESimulatorFoundation). Neither is necessary here: the release asset already
# contains the built web extension, and the wrapper app is small enough to
# assemble with the Command Line Tools that Homebrew already needs.
#
# So this formula builds the app bundle itself. The generated Xcode project of
# the App Store app (ajayyy/DeArrowSafari, pinned by commit) supplies the host
# app's status page and icon, and this formula writes the two Info.plists,
# compiles the extension and host executables with `xcrun clang`, and ad-hoc
# signs both bundles. Nothing is compiled from JavaScript and no npm is needed:
# upstream's release workflow runs webpack and zips `dist`.
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
  revision 1

  livecheck do
    url :stable
    strategy :github_latest
  end

  depends_on :macos

  # Upstream's generated Xcode project for the App Store app: the status page,
  # its resources and the app icon. Only those assets are used; the project
  # itself is not built. It is static glue around the webpack build, not a
  # release artifact, so it is pinned by commit and moved by hand when upstream
  # regenerates it for a new Xcode.
  resource "wrapper" do
    url "https://github.com/ajayyy/DeArrowSafari/archive/96cb6e0ed7024351f94fc205f70501813545c8ae.tar.gz"
    sha256 "893bde4900ce0ad3404df2083c84a5471f7ec5665f918868efb18f1970923d2f"
  end

  def install
    archive_root = "DeArrowSafari-96cb6e0ed7024351f94fc205f70501813545c8ae"
    system "tar", "-xzf", resource("wrapper").cached_download, "-C", buildpath
    wrapper = buildpath/archive_root
    odie "the wrapper archive did not extract to #{wrapper}" unless wrapper.directory?

    project = wrapper/"DeArrowSafari/DeArrow"
    shared = project/"Shared (App)"
    odie "the wrapper archive did not contain #{shared}" unless shared.directory?

    app = buildpath/"DeArrow.app"
    appex = app/"Contents/PlugIns/DeArrow Extension.appex"
    [app/"Contents/MacOS", app/"Contents/Resources/Base.lproj",
     appex/"Contents/MacOS", appex/"Contents/Resources"].each(&:mkpath)

    # The release zip holds exactly the built web extension's dist contents.
    system "unzip", "-q", cached_download, "-d", appex/"Contents/Resources"

    # The only native code in the extension is the message handler Safari
    # instantiates through NSExtensionPrincipalClass; it is called only when the
    # web extension sends a native message.
    (buildpath/"DeArrowExtension.m").write <<~OBJC
      #import <Foundation/Foundation.h>

      @interface SafariWebExtensionHandler : NSObject <NSExtensionRequestHandling>
      @end

      @implementation SafariWebExtensionHandler

      - (void)beginRequestWithExtensionContext:(NSExtensionContext *)context {
          NSExtensionItem *item = context.inputItems.firstObject;
          id message = item.userInfo[@"message"];
          NSExtensionItem *response = [[NSExtensionItem alloc] init];
          response.userInfo = @{ @"message": @{ @"Response to": message ?: [NSNull null] } };
          [context completeRequestReturningItems:@[response] completionHandler:nil];
      }

      @end
    OBJC
    system "xcrun", "--sdk", "macosx", "clang", "-mmacosx-version-min=12.0",
           "-fobjc-arc", "-O2", "-framework", "Foundation",
           "-Xlinker", "-e", "-Xlinker", "_NSExtensionMain",
           "-o", appex/"Contents/MacOS/DeArrow Extension",
           buildpath/"DeArrowExtension.m"
    (appex/"Contents/Info.plist").write <<~EOS
      <?xml version="1.0" encoding="UTF-8"?>
      <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
      <plist version="1.0">
      <dict>
      \t<key>CFBundleDevelopmentRegion</key>
      \t<string>en</string>
      \t<key>CFBundleDisplayName</key>
      \t<string>DeArrow Extension</string>
      \t<key>CFBundleExecutable</key>
      \t<string>DeArrow Extension</string>
      \t<key>CFBundleIdentifier</key>
      \t<string>dev.fmu.safari-ext-dearrow.Extension</string>
      \t<key>CFBundleInfoDictionaryVersion</key>
      \t<string>6.0</string>
      \t<key>CFBundleName</key>
      \t<string>DeArrow Extension</string>
      \t<key>CFBundlePackageType</key>
      \t<string>XPC!</string>
      \t<key>CFBundleShortVersionString</key>
      \t<string>#{version}</string>
      \t<key>CFBundleVersion</key>
      \t<string>#{version}</string>
      \t<key>LSMinimumSystemVersion</key>
      \t<string>12.0</string>
      \t<key>NSExtension</key>
      \t<dict>
      \t\t<key>NSExtensionPointIdentifier</key>
      \t\t<string>com.apple.Safari.web-extension</string>
      \t\t<key>NSExtensionPrincipalClass</key>
      \t\t<string>SafariWebExtensionHandler</string>
      \t</dict>
      </dict>
      </plist>
    EOS

    # The host app is only the container Safari loads the extension from; its
    # window is upstream's status page, loaded from the app's own resources.
    cp Dir[shared/"Resources/*"], app/"Contents/Resources"
    cp shared/"Base.lproj/Main.html", app/"Contents/Resources/Base.lproj"
    (buildpath/"DeArrow.m").write <<~OBJC
      #import <Cocoa/Cocoa.h>
      #import <SafariServices/SafariServices.h>
      #import <WebKit/WebKit.h>

      static NSString *const kExtensionBundleIdentifier = @"dev.fmu.safari-ext-dearrow.Extension";

      @interface AppDelegate : NSObject <NSApplicationDelegate, WKNavigationDelegate, WKScriptMessageHandler>
      @property(strong) NSWindow *window;
      @property(strong) WKWebView *webView;
      @end

      @implementation AppDelegate

      - (void)applicationDidFinishLaunching:(NSNotification *)notification {
          NSRect frame = NSMakeRect(0, 0, 480, 460);
          self.window = [[NSWindow alloc] initWithContentRect:frame
                                                   styleMask:(NSWindowStyleMaskTitled |
                                                              NSWindowStyleMaskClosable)
                                                     backing:NSBackingStoreBuffered
                                                       defer:NO];
          self.window.title = @"DeArrow";
          WKWebViewConfiguration *configuration = [[WKWebViewConfiguration alloc] init];
          [configuration.userContentController addScriptMessageHandler:self name:@"controller"];
          self.webView = [[WKWebView alloc] initWithFrame:frame configuration:configuration];
          self.webView.navigationDelegate = self;
          self.window.contentView = self.webView;
          [self.window center];
          [self.window makeKeyAndOrderFront:nil];
          NSURL *page = [[NSBundle mainBundle] URLForResource:@"Main" withExtension:@"html"];
          [self.webView loadFileURL:page allowingReadAccessToURL:[[NSBundle mainBundle] resourceURL]];
          [NSApp activateIgnoringOtherApps:YES];
      }

      - (void)webView:(WKWebView *)webView didFinishNavigation:(WKNavigation *)navigation {
          [webView evaluateJavaScript:@"show('mac')" completionHandler:nil];
          [SFSafariExtensionManager
              getStateOfSafariExtensionWithIdentifier:kExtensionBundleIdentifier
                                    completionHandler:^(SFSafariExtensionState *state, NSError *error) {
              if (state == nil || error != nil) {
                  return;
              }
              NSString *script = [NSString stringWithFormat:@"show('mac', %@)",
                                                            state.isEnabled ? @"true" : @"false"];
              dispatch_async(dispatch_get_main_queue(), ^{
                  [webView evaluateJavaScript:script completionHandler:nil];
              });
          }];
      }

      - (void)userContentController:(WKUserContentController *)controller
            didReceiveScriptMessage:(WKScriptMessage *)message {
          if (![message.body isKindOfClass:[NSString class]] ||
              ![message.body isEqualToString:@"open-preferences"]) {
              return;
          }
          [SFSafariApplication
              showPreferencesForExtensionWithIdentifier:kExtensionBundleIdentifier
                                     completionHandler:^(NSError *error) {
              if (error != nil) {
                  return;
              }
              dispatch_async(dispatch_get_main_queue(), ^{
                  [NSApp terminate:nil];
              });
          }];
      }

      - (BOOL)applicationShouldTerminateAfterLastWindowClosed:(NSApplication *)sender {
          return YES;
      }

      @end

      int main(void) {
          @autoreleasepool {
              NSApplication *application = [NSApplication sharedApplication];
              AppDelegate *delegate = [[AppDelegate alloc] init];
              application.delegate = delegate;
              [application setActivationPolicy:NSApplicationActivationPolicyRegular];
              [application run];
          }
          return 0;
      }
    OBJC
    system "xcrun", "--sdk", "macosx", "clang", "-mmacosx-version-min=12.0",
           "-fobjc-arc", "-O2", "-framework", "Cocoa", "-framework", "WebKit",
           "-framework", "SafariServices",
           "-o", app/"Contents/MacOS/DeArrow", buildpath/"DeArrow.m"

    iconset = buildpath/"AppIcon.iconset"
    iconset.mkpath
    icon_sources = shared/"Assets.xcassets/AppIcon.appiconset"
    {
      "icon_16x16.png"      => "mac-icon-16@1x.png",
      "icon_16x16@2x.png"   => "mac-icon-16@2x.png",
      "icon_32x32.png"      => "mac-icon-32@1x.png",
      "icon_32x32@2x.png"   => "mac-icon-32@2x.png",
      "icon_128x128.png"    => "mac-icon-128@1x.png",
      "icon_128x128@2x.png" => "mac-icon-128@2x.png",
      "icon_256x256.png"    => "mac-icon-256@1x.png",
      "icon_256x256@2x.png" => "mac-icon-256@2x.png",
      "icon_512x512.png"    => "mac-icon-512@1x.png",
      "icon_512x512@2x.png" => "mac-icon-512@2x.png",
    }.each do |target, source|
      cp icon_sources/source, iconset/target
    end
    system "iconutil", "-c", "icns", iconset, "-o", app/"Contents/Resources/AppIcon.icns"

    (app/"Contents/Info.plist").write <<~EOS
      <?xml version="1.0" encoding="UTF-8"?>
      <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
      <plist version="1.0">
      <dict>
      \t<key>CFBundleDevelopmentRegion</key>
      \t<string>en</string>
      \t<key>CFBundleDisplayName</key>
      \t<string>DeArrow</string>
      \t<key>CFBundleExecutable</key>
      \t<string>DeArrow</string>
      \t<key>CFBundleIconFile</key>
      \t<string>AppIcon</string>
      \t<key>CFBundleIdentifier</key>
      \t<string>dev.fmu.safari-ext-dearrow</string>
      \t<key>CFBundleInfoDictionaryVersion</key>
      \t<string>6.0</string>
      \t<key>CFBundleName</key>
      \t<string>DeArrow</string>
      \t<key>CFBundlePackageType</key>
      \t<string>APPL</string>
      \t<key>CFBundleShortVersionString</key>
      \t<string>#{version}</string>
      \t<key>CFBundleVersion</key>
      \t<string>#{version}</string>
      \t<key>LSApplicationCategoryType</key>
      \t<string>public.app-category.productivity</string>
      \t<key>LSMinimumSystemVersion</key>
      \t<string>12.0</string>
      \t<key>NSHighResolutionCapable</key>
      \t<true/>
      \t<key>NSPrincipalClass</key>
      \t<string>NSApplication</string>
      </dict>
      </plist>
    EOS

    # No development team: "Sign to Run Locally" is an ad-hoc signature, which
    # needs no certificate and is what Safari calls an unsigned extension.
    extension_entitlements = buildpath/"extension.entitlements"
    extension_entitlements.write <<~EOS
      <?xml version="1.0" encoding="UTF-8"?>
      <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
      <plist version="1.0">
      <dict>
      \t<key>com.apple.security.app-sandbox</key>
      \t<true/>
      \t<key>com.apple.security.files.user-selected.read-only</key>
      \t<true/>
      </dict>
      </plist>
    EOS
    app_entitlements = buildpath/"app.entitlements"
    app_entitlements.write <<~EOS
      <?xml version="1.0" encoding="UTF-8"?>
      <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
      <plist version="1.0">
      <dict>
      \t<key>com.apple.security.app-sandbox</key>
      \t<true/>
      \t<key>com.apple.security.files.user-selected.read-only</key>
      \t<true/>
      \t<key>com.apple.security.network.client</key>
      \t<true/>
      </dict>
      </plist>
    EOS
    system "codesign", "--force", "--sign", "-", "--timestamp=none",
           "--entitlements", extension_entitlements, appex
    system "codesign", "--force", "--sign", "-", "--timestamp=none",
           "--entitlements", app_entitlements, app

    prefix.install app
  end

  def caveats
    app = opt_prefix/"DeArrow.app"
    appex = app/"Contents/PlugIns/DeArrow Extension.appex"
    <<~EOS
      Safari only loads this extension from a signed app or, for this ad-hoc
      signed development build, after you allow unsigned extensions for the
      current Safari session. Open the installed app once to register the
      extension with PlugInKit:

        open "#{app}"

      If Safari's Extensions settings still do not list it, register the app
      extension explicitly and check again:

        pluginkit -a "#{appex}"
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

      After `brew upgrade`, open the app once more (the path above uses the opt
      prefix, which follows the new keg) so Safari sees the new build.
    EOS
  end

  test do
    app = prefix/"DeArrow.app"
    appex = app/"Contents/PlugIns/DeArrow Extension.appex"
    assert_path_exists app/"Contents/Info.plist"
    assert_path_exists app/"Contents/MacOS/DeArrow"
    assert_path_exists appex/"Contents/Info.plist"
    assert_path_exists appex/"Contents/MacOS/DeArrow Extension"
    assert_equal version.to_s,
                 shell_output("/usr/bin/plutil -extract CFBundleShortVersionString raw " \
                              "'#{app}/Contents/Info.plist'").strip
    assert_equal "com.apple.Safari.web-extension",
                 shell_output("/usr/bin/plutil -extract NSExtension.NSExtensionPointIdentifier raw " \
                              "'#{appex}/Contents/Info.plist'").strip
    manifest = JSON.parse((appex/"Contents/Resources/manifest.json").read)
    assert_equal version.to_s, manifest["version"]
    assert_match "Signature=adhoc", shell_output("/usr/bin/codesign -dv '#{app}' 2>&1")
    assert_match "Signature=adhoc", shell_output("/usr/bin/codesign -dv '#{appex}' 2>&1")
  end
end
