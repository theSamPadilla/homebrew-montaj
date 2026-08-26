class Montaj < Formula
  desc "Video editing toolkit — local-first, CLI-driven, agent-friendly"
  homepage "https://github.com/theSamPadilla/montaj"
  url "https://github.com/theSamPadilla/montaj/archive/refs/tags/v4.0.0.tar.gz"
  sha256 "d7a3947919d037e09134ca020631832236eea0a812d7d64b3d609e9ad0125cc4"
  license "MIT"
  head "https://github.com/theSamPadilla/montaj.git", branch: "main"

  depends_on "ffmpeg"
  depends_on "node"
  depends_on "python@3.12"

  skip_clean "libexec"

  def install
    python = formula_opt_bin("python@3.12")/"python3.12"
    # --copies makes the venv self-contained instead of symlinking back to
    # python@3.12; protects the install across keg upgrades or relocations.
    system python, "-m", "venv", "--copies", libexec
    system libexec/"bin/pip", "install", buildpath
    bin.install_symlink libexec/"bin/montaj"
    bin.install_symlink libexec/"bin/mtj"

    # Strip the pip-installed native libs' ad-hoc signatures before Homebrew's
    # post-install `fix_dynamic_linkage` rewrites their install-names via the
    # ruby-macho gem. On a SIGNED Mach-O that in-place write fails outright
    # ("Failed changing dylib ID", which fails the whole install); on an unsigned
    # one it succeeds. The libs are re-signed in post_install.
    each_native_lib { |lib| quiet_system "/usr/bin/codesign", "--remove-signature", lib } if OS.mac?
  end

  # Re-sign every native lib AFTER Homebrew's linkage fixup. That fixup rewrites
  # install-names (pydantic_core, Pillow's bundled dylibs, watchfiles, ...) and
  # leaves them unsigned/invalid, and Apple Silicon's AMFI (hard-enforced on
  # macOS Tahoe) SIGKILLs any process that maps an unsigned or invalidly signed
  # page — so `montaj serve`, `montaj --help`, and anything importing
  # pydantic/PIL would die with "Code Signature Invalid" without this.
  #
  # NOTE: Homebrew's fixup also tries to re-sign the libs it rewrote using its
  # own (ruby-macho) signer, which fails on watchfiles' Mach-O layout and prints
  # one non-fatal "Insertion at offset N is not valid" line. The install still
  # succeeds (exit 0) and this step re-signs watchfiles correctly with the
  # codesign CLI; the line is a cosmetic Homebrew limitation, not a real failure.
  def post_install
    if OS.mac?
      each_native_lib do |lib|
        quiet_system "/usr/bin/codesign", "--force", "--sign", "-", "--timestamp=none", lib
      end
    end
  end

  # FNM_DOTMATCH is required so the glob descends into dot-directories like
  # Pillow's bundled `PIL/.dylibs/` — otherwise those 17 dylibs are skipped.
  def each_native_lib
    glob = libexec/"lib/python*/site-packages/**/*.{so,dylib}"
    Dir.glob(glob, File::FNM_DOTMATCH).each do |lib|
      next if File.symlink?(lib) || !File.file?(lib)

      yield lib
    end
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
