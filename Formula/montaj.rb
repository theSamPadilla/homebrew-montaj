class Montaj < Formula
  desc "Video editing toolkit — local-first, CLI-driven, agent-friendly"
  homepage "https://github.com/theSamPadilla/montaj"
  url "https://github.com/theSamPadilla/montaj/archive/refs/tags/v2.1.3.tar.gz"
  sha256 "a39575b74329a794f4d06e1b8a00aa48b874d115964def826aac96cca6ecfb27"
  license "MIT"
  head "https://github.com/theSamPadilla/montaj.git", branch: "main"

  depends_on "ffmpeg"
  depends_on "node"
  depends_on "python@3.12"

  skip_clean "libexec"

  def install
    python = Formula["python@3.12"].opt_bin/"python3.12"
    # --copies makes the venv self-contained instead of symlinking back to
    # python@3.12; protects the install across keg upgrades or relocations.
    system python, "-m", "venv", "--copies", libexec
    system libexec/"bin/pip", "install", buildpath
    bin.install_symlink libexec/"bin/montaj"
    bin.install_symlink libexec/"bin/mtj"
  end

  def caveats
    <<~EOS
      First-run setup (one-time):
        montaj doctor               # diagnose what's missing — gives exact next steps
        montaj install ui           # almost always needed (builds UI into ~/.cache/montaj/)

      HDR video support requires ffmpeg built with zscale (libzimg).
      Homebrew's default ffmpeg does NOT include it. Fix:
        montaj install ffmpeg
      Or run `montaj doctor` for manual alternatives.

      Optional:
        montaj install whisper      # transcription model weights
        montaj install rvm          # background-removal weights
    EOS
  end

  test do
    system bin/"montaj", "--help"
    system bin/"mtj", "--help"
  end
end
