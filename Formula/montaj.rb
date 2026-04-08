class Montaj < Formula
  include Language::Python::Virtualenv
  desc "Video editing toolkit — local-first, CLI-driven, agent-friendly"
  homepage "https://github.com/theSamPadilla/montaj"
  url "https://github.com/theSamPadilla/montaj/archive/refs/tags/v0.1.0.tar.gz"
  sha256 "678c04da9fb03be37c8a7a04af5a184b1a1a27a9c378e4ca04e560c36a33758d"
  license "MIT"
  head "https://github.com/theSamPadilla/montaj.git", branch: "main"

  depends_on "node"
  depends_on "python@3.12"

  def install
    # Python CLI, steps, and server
    venv = virtualenv_create(libexec, "python3.12")
    venv.pip_install_and_link buildpath

    # Render engine
    system "npm", "install", "--prefix", "#{buildpath}/render"

    # UI — install and build
    system "npm", "install", "--prefix", "#{buildpath}/ui"
    system "npm", "run", "build", "--prefix", "#{buildpath}/ui"
  end

  def caveats
    <<~EOS
      Download whisper model weights to enable transcription:
        montaj install whisper

      Optional — background removal support:
        montaj install rvm

      API keys for adaptors are stored in:
        ~/.montaj/credentials.json
    EOS
  end

  test do
    system bin/"montaj", "--help"
    system bin/"mtj", "--help"
  end
end
