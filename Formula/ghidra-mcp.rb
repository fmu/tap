class GhidraMcp < Formula
  include Language::Python::Virtualenv

  desc "MCP server exposing Ghidra reverse-engineering tools to LLM clients"
  homepage "https://github.com/LaurieWired/GhidraMCP"
  url "https://github.com/LaurieWired/GhidraMCP/releases/download/2.0/GhidraMCP-release-2-0.zip"
  sha256 "ebf904fd6782e429e95a60a24fe0724b20c0acb2dedb304135a5281f6b5f2e72"
  license "Apache-2.0"

  livecheck do
    url :homepage
    strategy :github_latest
  end

  # Ghidra extensions are built against one exact Ghidra release and a
  # mismatched one only fails later, inside the affected tool, so this formula
  # installs the extension next to the Ghidra keg it was built for. The bump
  # script aborts instead of pinning a release built for another version.
  depends_on "certifi" => :no_linkage
  depends_on "cryptography" => :no_linkage
  depends_on "fmu/tap/ghidra@12.1"
  depends_on "pydantic" => :no_linkage
  depends_on "python@3.15"
  depends_on "rpds-py" => :no_linkage

  # These four ship native extensions built for python@3.15 by Homebrew, so the
  # formulae provide them and their own dependencies (cffi, pydantic-core, ...).
  pypi_packages exclude_packages: %w[certifi cryptography pydantic rpds-py]

  resource "anyio" do
    url "https://files.pythonhosted.org/packages/a9/d2/f4d173e22df740bc37b1db102b386ba719b66e95b0f0d751f556b387e6d2/anyio-4.15.1.tar.gz"
    sha256 "9f28306018cbd6d329e64a36d58256edff76dd996fe423bc957326e578b82a94"
  end

  resource "attrs" do
    url "https://files.pythonhosted.org/packages/9a/8e/82a0fe20a541c03148528be8cac2408564a6c9a0cc7e9171802bc1d26985/attrs-26.1.0.tar.gz"
    sha256 "d03ceb89cb322a8fd706d4fb91940737b6642aa36998fe130a9bc96c985eff32"
  end

  resource "charset-normalizer" do
    url "https://files.pythonhosted.org/packages/33/1c/f41d4e74c28ab327ff3acd36053f7ea506c55872d7a90b0fa71aa3ab0c89/charset_normalizer-3.5.2.tar.gz"
    sha256 "39de2a259fc954455c57274dc94c79d5842774e1247a016aff30bc0efed0f4ef"
  end

  resource "click" do
    url "https://files.pythonhosted.org/packages/c7/0e/7fa0ef50764b67090eca4114772a2abf8b6148198475e54c660b97caeee6/click-8.5.0.tar.gz"
    sha256 "ba0d2089de75ea0310e2dde03160e6ca10009947fb95a182f9b54021bb272e34"
  end

  resource "h11" do
    url "https://files.pythonhosted.org/packages/01/ee/02a2c011bdab74c6fb3c75474d40b3052059d95df7e73351460c8588d963/h11-0.16.0.tar.gz"
    sha256 "4e35b956cf45792e4caa5885e69fba00bdbc6ffafbfa020300e549b208ee5ff1"
  end

  resource "httpcore" do
    url "https://files.pythonhosted.org/packages/06/94/82699a10bca87a5556c9c59b5963f2d039dbd239f25bc2a63907a05a14cb/httpcore-1.0.9.tar.gz"
    sha256 "6e34463af53fd2ab5d807f399a9b45ea31c3dfa2276f15a2c3f00afff6e176e8"
  end

  resource "httpx" do
    url "https://files.pythonhosted.org/packages/b1/df/48c586a5fe32a0f01324ee087459e112ebb7224f646c0b5023f5e79e9956/httpx-0.28.1.tar.gz"
    sha256 "75e98c5f16b0f35b567856f597f06ff2270a374470a5c2392242528e3e3e42fc"
  end

  resource "httpx-sse" do
    url "https://files.pythonhosted.org/packages/0f/4c/751061ffa58615a32c31b2d82e8482be8dd4a89154f003147acee90f2be9/httpx_sse-0.4.3.tar.gz"
    sha256 "9b1ed0127459a66014aec3c56bebd93da3c1bc8bb6618c8082039a44889a755d"
  end

  resource "idna" do
    url "https://files.pythonhosted.org/packages/f5/08/8eea9d4b8302028f3abb2c0813953f7aec26d33b7a8960ed760e65ff29fa/idna-3.20.tar.gz"
    sha256 "a7db850025b95ded1eae8a46181a1a6c56c92c96f0e2b005d9ff8dc0210cab44"
  end

  resource "jsonschema" do
    url "https://files.pythonhosted.org/packages/b3/fc/e067678238fa451312d4c62bf6e6cf5ec56375422aee02f9cb5f909b3047/jsonschema-4.26.0.tar.gz"
    sha256 "0c26707e2efad8aa1bfc5b7ce170f3fccc2e4918ff85989ba9ffa9facb2be326"
  end

  resource "jsonschema-specifications" do
    url "https://files.pythonhosted.org/packages/19/74/a633ee74eb36c44aa6d1095e7cc5569bebf04342ee146178e2d36600708b/jsonschema_specifications-2025.9.1.tar.gz"
    sha256 "b540987f239e745613c7a9176f3edb72b832a4ac465cf02712288397832b5e8d"
  end

  resource "mcp" do
    url "https://files.pythonhosted.org/packages/ba/93/0142dc84a666daf8ad51a34268f34c12fd6fda4f3810c4be2504eecc8212/mcp-1.30.0.tar.gz"
    sha256 "445414625fce5c295faa505bb11bacece661ab6f4028d57c935db57820b7a3e4"
  end

  resource "pydantic-settings" do
    url "https://files.pythonhosted.org/packages/d0/31/21d21e0e38a8f5f7a7f0cde22820117b6d17d6bc36f348129527f915d7f4/pydantic_settings-2.16.2.tar.gz"
    sha256 "3dc08ffabed2bbd5dc2dd55ead7b78b4e4c5cd776aecd04310db5f1224caaf46"
  end

  resource "pyjwt" do
    url "https://files.pythonhosted.org/packages/43/ea/5194e52748b0da83d71e082d75496eaec6e58f419f5e184786ded517e6a9/pyjwt-2.15.1.tar.gz"
    sha256 "4f259e80cdfb6b3fc18a7de51fd1ef9ec79652f25019bae68975ca2468a34df8"
  end

  resource "python-dotenv" do
    url "https://files.pythonhosted.org/packages/74/26/2fbeedb218a787a5eea551c7532cac4e009f83d689dd2faa0d0353473f86/python_dotenv-1.2.4.tar.gz"
    sha256 "f0d53e69935a851c0dcc78f3ab7aaccd8cabef0b92382b576b824212902873c0"
  end

  resource "python-multipart" do
    url "https://files.pythonhosted.org/packages/9f/b7/15b905f6142a9a8a68f66900788da1a32e4d4254452783b37ad1eccb0506/python_multipart-0.0.33.tar.gz"
    sha256 "b8112424a6abd162ec08d390565dd113ad699f2fe6fef3c987b8bbcbfe9e390d"
  end

  resource "referencing" do
    url "https://files.pythonhosted.org/packages/22/f5/df4e9027acead3ecc63e50fe1e36aca1523e1719559c499951bb4b53188f/referencing-0.37.0.tar.gz"
    sha256 "44aefc3142c5b842538163acb373e24cce6632bd54bdb01b21ad5863489f50d8"
  end

  resource "requests" do
    url "https://files.pythonhosted.org/packages/ac/c3/e2a2b89f2d3e2179abd6d00ebd70bff6273f37fb3e0cc209f48b39d00cbf/requests-2.34.2.tar.gz"
    sha256 "f288924cae4e29463698d6d60bc6a4da69c89185ad1e0bcc4104f584e960b9ed"
  end

  resource "sniffio" do
    url "https://files.pythonhosted.org/packages/a2/87/a6771e1546d97e7e041b6ae58d80074f81b7d5121207425c964ddf5cfdbd/sniffio-1.3.1.tar.gz"
    sha256 "f4324edc670a0f49750a81b895f35c3adb843cca46f0530f79fc1babb23789dc"
  end

  resource "sse-starlette" do
    url "https://files.pythonhosted.org/packages/71/7f/3b8ec4f27833f7b8c270a3ef960b6d435e1065439847bc0fcd1e58ae898b/sse_starlette-3.6.0.tar.gz"
    sha256 "623151d6c20dc0eebf1b3379c27faae91fff883bac7ab6665f16f46440a88b3a"
  end

  resource "starlette" do
    url "https://files.pythonhosted.org/packages/48/bb/3d8757f21e9a53d9035c9eb039a777047139a16bfdbedfc7a58241c3d914/starlette-1.10.0.tar.gz"
    sha256 "b8399098d4c1e3522734f7235dc79b1fc967f96cf139c81e0fa30479e0685f9b"
  end

  resource "typing-extensions" do
    url "https://files.pythonhosted.org/packages/f6/cc/6253133b5bb138fc3306cebfbda2c520f545d36b5be2c7255cc528bb45d6/typing_extensions-4.16.0.tar.gz"
    sha256 "dc983d19a509c94dba722ee6abd33940f7c05a89e243c47e907eb4db6f1a43e5"
  end

  resource "typing-inspection" do
    url "https://files.pythonhosted.org/packages/a3/26/b09b8010994eccc3c09092e6b34058f36a460eea2d4c3e8b910c695975a0/typing_inspection-0.4.4.tar.gz"
    sha256 "547274fa6b0a561ccf549cc9524b999a578e737d015d8709d021f9d0d13bea47"
  end

  resource "urllib3" do
    url "https://files.pythonhosted.org/packages/e3/05/b17359e1cefb4f909b5e40b1b90a496d987258916dbbf88e842c729f510e/urllib3-2.8.0.tar.gz"
    sha256 "63bf2ead4c879426ebf22ef2a781eeb4aa3b4ae798a0435506f8687fd5bb9b63"
  end

  resource "uvicorn" do
    url "https://files.pythonhosted.org/packages/da/34/30e9280707135d2cfc589dfff3cb796bd07a3aeb1a3e415ba09dd89d7bb4/uvicorn-0.54.0.tar.gz"
    sha256 "a2e33cbfaa0306f8e6b0c13e0cb89d7d7a2da3e62b90c66e18c33d9807b28620"
  end

  def install
    # Homebrew unpacks the release zip into `buildpath`; it usually drops the
    # single top-level directory, but older/newer unpack strategies differ, so
    # look for both halves of the release wherever they landed.
    extension = Pathname.glob("**/ghidra_*_PUBLIC_*_GhidraMCP.zip").first
    sdist = Pathname.glob("**/ghidra_mcp-*.tar.gz").first
    if extension.nil? || sdist.nil?
      odie "the release archive did not contain the Ghidra extension and the Python sdist"
    end

    # The extension is what Ghidra loads; the sdist is the MCP server that
    # clients launch.
    libexec.install extension

    system "tar", "-xzf", sdist
    sdist_root = Pathname.glob("**/ghidra_mcp-*/").first
    odie "could not unpack the ghidra-mcp Python sdist" if sdist_root.nil?

    venv = virtualenv_create(libexec, "python3.15")
    venv.pip_install resources
    venv.pip_install_and_link sdist_root
  end

  def caveats
    # `brew info` prints caveats before the formula is installed, when the
    # parked extension (whose name carries the Ghidra version) is not there.
    extension = Pathname.glob(libexec/"ghidra_*_GhidraMCP.zip").first
    extension_name = extension ? extension.basename.to_s : "ghidra_*_PUBLIC_*_GhidraMCP.zip"
    ghidra_version = (extension && extension.basename.to_s[/ghidra_(.+)_PUBLIC_/, 1]) || "<ghidra-version>"
    <<~EOS
      This installs the `ghidra-mcp` MCP server and the matching Ghidra
      extension, which Homebrew parks here:

        #{opt_libexec}/#{extension_name}

      Homebrew cannot register Ghidra extensions, so do that once after Ghidra
      has been started at least once (it creates the `.ghidra_*_PUBLIC` user
      directory). Either use Ghidra's File > Install Extensions > "+" and select
      the zip above, or run:

        unzip -d ~/.ghidra/.ghidra_#{ghidra_version}_PUBLIC/Extensions #{opt_libexec}/#{extension_name}

      Restart Ghidra, then enable GhidraMCPPlugin under File > Configure > Developer.

      Add the server to your MCP client, for example:

        {
          "mcpServers": {
            "ghidra": {
              "command": "#{opt_bin}/ghidra-mcp",
              "args": ["--ghidra-server", "http://127.0.0.1:8080/"]
            }
          }
        }
    EOS
  end

  test do
    # Upstream has no --version flag, so the console script is checked through
    # --help (which also imports the whole server) and the package metadata.
    assert_match "MCP server for Ghidra", shell_output("#{bin}/ghidra-mcp --help")
    metadata = shell_output(
      "#{libexec}/bin/python -c \"import importlib.metadata as m; print(m.version('ghidra-mcp'))\"",
    ).strip
    assert_match(/\A#{Regexp.escape(version.to_s)}(?:\.0)?\z/, metadata)

    system libexec/"bin/python", "-c", "import ghidra_mcp"

    extension = Pathname.glob(libexec/"ghidra_*_PUBLIC_*_GhidraMCP.zip").first
    assert extension, "the Ghidra extension zip was not installed"

    # The extension has to target the exact Ghidra keg this formula depends on.
    unzip_dir = testpath/"extension"
    system "unzip", "-q", extension, "-d", unzip_dir
    properties = (unzip_dir/"GhidraMCP/extension.properties").read
    ghidra = Utils::Path.formula_opt_libexec("fmu/tap/ghidra@12.1")/"Ghidra/application.properties"
    ghidra_version = ghidra.read[/application\.version=(.+)/, 1]
    assert_match(/^version=#{Regexp.escape(ghidra_version)}$/, properties)
  end
end
