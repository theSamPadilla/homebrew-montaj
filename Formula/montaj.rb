class Montaj < Formula
  desc "Video editing toolkit — local-first, CLI-driven, agent-friendly"
  homepage "https://github.com/theSamPadilla/montaj"
  url "https://github.com/theSamPadilla/montaj/archive/refs/tags/v2.0.3.tar.gz"
  sha256 "85e860b21a246185db8b9fdaad56fc9d96e4e80b6fa628b5365ac303e7982c09"
  license "MIT"
  head "https://github.com/theSamPadilla/montaj.git", branch: "main"

  # No native dylibs to relocate — everything runs inside a Python venv.
  # Without this, Homebrew fails on Rust-compiled wheels (e.g. nh3) whose
  # compact Mach-O headers can't be rewritten by install_name_tool.
  pour_bottle? only_if: :any_skip_relocation

  depends_on "ffmpeg"
  depends_on "node"
  depends_on "python@3.12"

  skip_clean "libexec"

  def install
    # Python CLI, steps, and server — explicit venv so all deps land in libexec
    python = Formula["python@3.12"].opt_bin/"python3.12"
    system python, "-m", "venv", libexec
    system libexec/"bin/pip", "install", buildpath
    bin.install_symlink libexec/"bin/montaj"
    bin.install_symlink libexec/"bin/mtj"

    # Render engine
    system "npm", "install", "--prefix", "#{buildpath}/render"

    # UI — install and build
    system "npm", "install", "--prefix", "#{buildpath}/ui"
    system "npm", "run", "build", "--prefix", "#{buildpath}/ui"
  end

  def caveats
    <<~EOS
      Run montaj doctor to verify your setup.

      HDR video support requires ffmpeg built with zscale (libzimg).
      Homebrew's default ffmpeg does NOT include it. Fix:
        montaj install ffmpeg
      Or run `montaj doctor` for manual alternatives.

      Download whisper model weights to enable transcription:
        montaj install whisper

      Optional — background removal support:
        montaj install rvm
    EOS
  end

  test do
    system bin/"montaj", "--help"
    system bin/"mtj", "--help"
  end
end
