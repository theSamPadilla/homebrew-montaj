class Montaj < Formula
  desc "Video editing toolkit — local-first, CLI-driven, agent-friendly"
  homepage "https://github.com/theSamPadilla/montaj"
  url "https://github.com/theSamPadilla/montaj/archive/refs/tags/v4.6.8.tar.gz"
  sha256 "171e03622a7571c1876ee2f19b7670afec3ea9f2d8f05b9f15b277f5fd750e23"
  license "MIT"
  head "https://github.com/theSamPadilla/montaj.git", branch: "main"

  depends_on "node"
  depends_on "python@3.12"

  # montaj bundles its own ffmpeg/ffprobe instead of depending on Homebrew's
  # ffmpeg formula because HDR video support requires zscale (libzimg), which
  # Homebrew-core's ffmpeg does not build in. These are pinned, checksummed
  # static builds from https://ffmpeg.martin-riedl.de (config includes
  # --enable-libzimg). The same pins are mirrored in montaj's
  # lib/ffmpeg_static.py (used by the non-Homebrew managed-install path), and
  # a sync test in montaj's test suite asserts the two stay in lockstep, so
  # update both sides together on a version bump. Only one of the branches
  # below is ever evaluated for a given install, so the repeated "ffmpeg" /
  # "ffprobe" resource names never actually collide.
  on_macos do
    on_arm do
      resource "ffmpeg" do
        url "https://ffmpeg.martin-riedl.de/download/macos/arm64/1783011502_8.1.2/ffmpeg.zip"
        sha256 "ef1aa60006c7b77ce170c1608c08d8e4ba1c30c5746f2ac986ded932d0ac2c3c"
      end

      resource "ffprobe" do
        url "https://ffmpeg.martin-riedl.de/download/macos/arm64/1783011502_8.1.2/ffprobe.zip"
        sha256 "c39787f4af7a3932502d2d48db6f6feaaa836b48a73ef78c32cc3285df61dfaf"
      end
    end

    on_intel do
      resource "ffmpeg" do
        url "https://ffmpeg.martin-riedl.de/download/macos/amd64/1783018342_8.1.2/ffmpeg.zip"
        sha256 "a52ef43883f44c219766d4b3bdde4e635b35465d0b704c01c3a0566b59775df9"
      end

      resource "ffprobe" do
        url "https://ffmpeg.martin-riedl.de/download/macos/amd64/1783018342_8.1.2/ffprobe.zip"
        sha256 "5408ca588c8c72b0dde3afe676d0a7acf25ef97e55ae6eba5c7bede1cda42695"
      end
    end
  end

  on_linux do
    on_intel do
      resource "ffmpeg" do
        url "https://ffmpeg.martin-riedl.de/download/linux/amd64/1783011670_8.1.2/ffmpeg.zip"
        sha256 "56452c0bfc4ee0325cd615d62f46ba8264f62eed34f727c2224c6c84fa7b8719"
      end

      resource "ffprobe" do
        url "https://ffmpeg.martin-riedl.de/download/linux/amd64/1783011670_8.1.2/ffprobe.zip"
        sha256 "c6f2d36e98f9a4445fad0b0be539f4c4faf13fd502116bf131becd53f56cd390"
      end
    end

    on_arm do
      resource "ffmpeg" do
        url "https://ffmpeg.martin-riedl.de/download/linux/arm64/1783010599_8.1.2/ffmpeg.zip"
        sha256 "ab9e16864b6bf4ae7e13bbdbdc29621be11a5c547c57af8d4250e9fa2f5e6461"
      end

      resource "ffprobe" do
        url "https://ffmpeg.martin-riedl.de/download/linux/arm64/1783010599_8.1.2/ffprobe.zip"
        sha256 "fb78317b81cdeb614533be59e489019b754afd199670666af28f0e9574be395b"
      end
    end
  end

  skip_clean "libexec"

  def install
    python = formula_opt_bin("python@3.12")/"python3.12"
    # --copies makes the venv self-contained instead of symlinking back to
    # python@3.12; protects the install across keg upgrades or relocations.
    system python, "-m", "venv", "--copies", libexec
    system libexec/"bin/pip", "install", buildpath
    bin.install_symlink libexec/"bin/montaj"
    bin.install_symlink libexec/"bin/mtj"

    # For this venv, sys.prefix == libexec, so lib/common.py's ffmpeg/ffprobe
    # resolver finds these at sys.prefix/vendor/ffmpeg/. They're deliberately
    # NOT symlinked into bin/, to avoid colliding with a user's own ffmpeg on
    # PATH. They're also static + notarized, so Homebrew's fix_dynamic_linkage
    # has nothing to relocate and their signature stays valid as-is, which is
    # why they live outside each_native_lib's glob and must not be re-signed.
    (libexec/"vendor/ffmpeg").mkpath
    resource("ffmpeg").stage  { (libexec/"vendor/ffmpeg").install "ffmpeg" }
    resource("ffprobe").stage { (libexec/"vendor/ffmpeg").install "ffprobe" }
    chmod 0755, [libexec/"vendor/ffmpeg/ffmpeg", libexec/"vendor/ffmpeg/ffprobe"]

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
