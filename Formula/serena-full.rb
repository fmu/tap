# serena-full is the "every language server Homebrew can install" variant of
# Formula/serena.rb, following the same pattern as Formula/rea-full.rb: it
# depends on serena and on the language-server formulae, installs the servers
# Homebrew does not package into its own keg, and installs
# `serena`/`serena-agent`/`serena-hooks` launchers that point SolidLSP at all of
# them. One `brew install` then produces a Serena that never downloads a
# language server on first use.
#
# Where each server comes from:
#
#   python      pyright            installed as a dependency below
#   go          gopls + go         PATH lookup in Serena's gopls adapter
#   ruby        ruby-lsp + ruby    PATH lookup in Serena's ruby adapter
#   rust        rust-analyzer      ls_path
#   toml        taplo              ls_path
#   terraform   terraform-ls       ls_path (honoured by the adapter patch in serena)
#   html        vscode-html-language-server
#   typescript  typescript-language-server + typescript   installed below
#   javascript  same servers as typescript
#   scss/css    some-sass-language-server                 installed below
#   astro       @astrojs/language-server + companion stack installed below
#   markdown    marksman                                  installed below
#
# The launchers export SERENA_TAP_LS_SPECIFIC_SETTINGS, which serena's config
# loader merges into `ls_specific_settings`, and SERENA_TAP_ASTRO_LSP_DIR for
# Astro's companion stack, which has no ls_path. A setting already present in
# the user's ~/.serena/serena_config.yml wins over the launcher's defaults, and
# gopls/ruby-lsp resolve their executable through PATH, so the launcher also
# prepends the pinned kegs and Homebrew's bin.
#
# `serena` and `serena-full` both provide `bin/serena`, `bin/serena-agent` and
# `bin/serena-hooks`: they are alternatives, not additions (see the caveats).
#
# Not pre-installed: Nix (Homebrew packages neither nixd nor nix) and GraphQL
# (Serena 2.1.0 has no GraphQL adapter, although the documentation on main
# describes it). Terraform still needs the `terraform` CLI, which Homebrew
# stopped packaging after the licence change; the language server is pinned.
#
# The versions installed below mirror the defaults of the SolidLSP release
# Formula/serena.rb pins; scripts/bump/serena.py re-pins the URL and tag.
class SerenaFull < Formula
  desc "Serena with every language server Homebrew can install, pinned"
  homepage "https://github.com/oraios/serena"
  url "https://github.com/oraios/serena.git",
      tag:      "v2.1.0",
      revision: "5e4f5cd173c7ff3eed37ee3f1de6c266b937c5dc"
  license "GPL-3.0-or-later"

  livecheck do
    url :homepage
    strategy :github_latest
  end

  # Named with the tap, like rea-full's `fmu/tap/rea`: another tap may ship a
  # formula called `serena`, and an unqualified dependency could then refuse to
  # resolve.
  depends_on "fmu/tap/serena"
  depends_on "go"
  depends_on "gopls"
  depends_on "node"
  # Transitive through serena, but named because the launcher points Python at
  # this keg's pyright-langserver.
  depends_on "pyright"
  depends_on "ruby"
  depends_on "ruby-lsp"
  depends_on "rust-analyzer"
  depends_on "taplo"
  depends_on "terraform-ls"
  depends_on "vscode-langservers-extracted"

  # serena, serena-full and serena-jetbrains are alternatives that own the same
  # commands; whichever is installed last takes them over.
  link_overwrite "bin/serena", "bin/serena-agent", "bin/serena-hooks"

  # Marksman publishes a single macOS binary, and Homebrew's formula for it
  # depends on an end-of-life dotnet. SolidLSP would otherwise download exactly
  # this release into ~/.solidlsp on the first Markdown project.
  resource "marksman" do
    url "https://github.com/artempyanykh/marksman/releases/download/2024-12-18/marksman-macos"
    sha256 "7e18803966231a33ee107d0d26f69b41f2f0dc1332c52dd9729c2e29fb77be83"
  end

  # The language servers that Homebrew does not package are installed into a
  # private prefix at the versions this Serena release's SolidLSP defaults to.
  # `--prefix` produces the local-style node_modules layout whose
  # node_modules/.bin launchers the ls_path settings point at.
  def install_npm_language_servers(prefix, packages)
    prefix.mkpath
    system "npm", "install", *std_npm_args(prefix: false), "--prefix", prefix.to_s, *packages
  end

  # Every language server the launchers pin, keyed by the name SolidLSP uses in
  # `ls_specific_settings`. The versions mirror Serena 2.1.0's SolidLSP defaults;
  # pyright and the Homebrew-packaged servers are pinned by their formulae.
  def language_servers
    typescript = opt_libexec/"language-servers/typescript/node_modules/.bin/typescript-language-server"
    sass = opt_libexec/"language-servers/some-sass/node_modules/.bin/some-sass-language-server"
    {
      "python"     => formula_opt_bin("pyright")/"pyright-langserver",
      "typescript" => typescript,
      "astro"      => opt_libexec/"astro-lsp/node_modules/.bin/astro-ls",
      "html"       => formula_opt_bin("vscode-langservers-extracted")/"vscode-html-language-server",
      "scss"       => sass,
      "markdown"   => opt_libexec/"marksman",
      "rust"       => formula_opt_bin("rust-analyzer")/"rust-analyzer",
      "toml"       => formula_opt_bin("taplo")/"taplo",
      "terraform"  => formula_opt_bin("terraform-ls")/"terraform-ls",
    }
  end

  def install
    prefix.install_metafiles

    install_npm_language_servers(libexec/"language-servers/typescript",
                                 ["typescript@5.9.3", "typescript-language-server@5.1.3"])
    install_npm_language_servers(libexec/"language-servers/some-sass",
                                 ["some-sass-language-server@2.3.8"])
    # Astro needs @astrojs/language-server plus the companion TypeScript server,
    # tsserver and @astrojs/ts-plugin; Serena's adapter expects them together in
    # one node_modules tree, which the keg's astro-lsp directory provides.
    install_npm_language_servers(libexec/"astro-lsp",
                                 ["@astrojs/language-server@2.17.0", "@astrojs/ts-plugin@1.10.10",
                                  "typescript@5.9.3", "typescript-language-server@5.1.3"])

    resource("marksman").stage do
      libexec.install Pathname.pwd.children.first => "marksman"
    end
    chmod 0755, libexec/"marksman"

    # The settings are handed to SolidLSP through the environment instead of
    # editing the user's configuration, so `brew upgrade` and a user's explicit
    # ls_specific_settings keep working. The JSON is single-quoted: it carries
    # only double quotes.
    settings_json = language_servers.transform_values { |executable| { "ls_path" => executable.to_s } }.to_json

    # gopls and ruby-lsp resolve their executable through PATH and have no
    # ls_path setting, and MCP clients may launch the server with a minimal
    # PATH, so the launchers prepend the pinned kegs (and node, for the npm
    # servers) plus Homebrew's bin. They exec the serena keg's console scripts,
    # resolved through the stable opt path, for the same command name.
    path_dirs = %w[go gopls node ruby ruby-lsp].map { |dependency| formula_opt_bin(dependency) }
    path_dirs << (HOMEBREW_PREFIX/"bin")
    %w[serena serena-agent serena-hooks].each do |command|
      (bin/command).write <<~SH
        #!/bin/bash
        export PATH="#{path_dirs.join(":")}:$PATH"
        export SERENA_TAP_LS_SPECIFIC_SETTINGS='#{settings_json}'
        export SERENA_TAP_ASTRO_LSP_DIR="#{opt_libexec}/astro-lsp"
        exec "#{formula_opt_libexec("serena")}/bin/#{command}" "$@"
      SH
      (bin/command).chmod 0755
    end
  end

  def caveats
    <<~EOS
      This formula initialises and configures Serena like the plain `serena`
      formula, but all language servers are pre-installed and pinned, so
      `serena init` needs no download on first project activation:

        serena init
        serena setup <client>

      Pinned: pyright (Python), gopls with the Go toolchain, ruby-lsp with Ruby,
      rust-analyzer, taplo (TOML), terraform-ls, vscode-html-language-server
      (HTML), typescript-language-server with TypeScript, some-sass-language-server
      (SCSS/CSS), @astrojs/language-server and marksman (Markdown).

      This formula is an alternative to the plain `serena` formula, not an
      addition: both provide `bin/serena`, `bin/serena-agent` and
      `bin/serena-hooks`, and installing one after the other replaces those
      commands (Homebrew reports the overwritten links). Removed together with
      Homebrew's autoremove, the `serena` dependency keg is gone; reinstall it,
      or `brew install fmu/tap/serena-full` again, to get the configured
      launchers back. To swap back to the plain CLI while this formula is
      installed:

        brew unlink serena && brew link serena

      The launchers export the server paths, so no shell profile is needed and
      the client registrations written by `serena setup` keep them. A setting
      already present in ~/.serena/serena_config.yml wins over the launcher's
      defaults.

      What the formula cannot pin: Rust projects need a toolchain (rustup) on
      PATH for rust-analyzer to load them; Terraform needs the `terraform` CLI,
      which Homebrew does not package (use hashicorp/tap); and the experimental
      HTML, Markdown and SCSS/CSS servers must be enabled per project in
      .serena/project.yml, e.g. `language_servers: [markdown]`.

      Not pre-installed: Nix (Homebrew packages neither nixd nor nix) and GraphQL
      (Serena 2.1.0 has no GraphQL adapter). `uv` remains available for the other
      PyPI-only language servers (ty, pyrefly, ...); it caches downloads under
      ~/.solidlsp and uv's data directory. Set SERENA_HOME to keep Serena's own
      configuration elsewhere.

      The optional dashboard uses pywebview and pystray, from the serena keg.
    EOS
  end

  test do
    assert_match "Serena #{version}", shell_output("#{bin}/serena --version")
    assert_match "start-mcp-server", shell_output("#{bin}/serena --help")

    launcher = (bin/"serena").read
    assert_match "SERENA_TAP_LS_SPECIFIC_SETTINGS", launcher
    assert_match "SERENA_TAP_ASTRO_LSP_DIR", launcher
    assert_match formula_opt_bin("gopls").to_s, launcher
    assert_match formula_opt_bin("ruby-lsp").to_s, launcher
    assert_match formula_opt_libexec("serena").to_s, launcher

    expected = language_servers.transform_values(&:to_s)
    language_servers.each_value { |executable| assert_predicate executable, :executable? }

    # The launcher's JSON must parse and name every pinned server.
    settings_json = launcher[/SERENA_TAP_LS_SPECIFIC_SETTINGS='([^']*)'/, 1]
    assert settings_json
    settings = JSON.parse(settings_json)
    assert_equal expected.keys.sort, settings.keys.sort
    settings.each { |language, value| assert_equal expected[language], value["ls_path"] }

    # Astro's adapter also needs the companion tsserver and plugin in one tree.
    assert_path_exists opt_libexec/"astro-lsp/node_modules/typescript/lib/tsserver.js"
    assert_path_exists opt_libexec/"astro-lsp/node_modules/@astrojs/ts-plugin"

    # End to end: the launcher's environment reaches SolidLSP's configuration
    # through the serena keg's hooks, and the Astro directory is honoured.
    ENV["SERENA_HOME"] = (testpath/"home").to_s
    config_path = testpath/"home/serena_config.yml"
    system formula_opt_libexec("serena")/"bin/python", "-c", <<~PY
      from serena.config.serena_config import SerenaConfig
      from serena.language_backend import BuiltinLanguageBackend
      SerenaConfig.init(builtin_language_backend=BuiltinLanguageBackend.LSP)
    PY
    ENV["SERENA_TAP_LS_SPECIFIC_SETTINGS"] = settings_json
    ENV["SERENA_TAP_ASTRO_LSP_DIR"] = (opt_libexec/"astro-lsp").to_s
    system formula_opt_libexec("serena")/"bin/python", "-c", <<~PY, config_path, settings_json
      import json, os, sys
      from serena.config.serena_config import SerenaConfig
      from solidlsp.language_servers.astro_language_server import AstroLanguageServer

      configured = SerenaConfig.from_config_file().ls_specific_settings
      expected = json.loads(sys.argv[2])
      for language, value in expected.items():
          assert configured[language]["ls_path"] == value["ls_path"], (language, configured.get(language))

      fake = type("Fake", (), {"_custom_settings": {}, "_ls_resources_dir": "/nonexistent"})()
      assert AstroLanguageServer._get_install_dir(fake) == os.environ["SERENA_TAP_ASTRO_LSP_DIR"]
    PY
  end
end
