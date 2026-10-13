class Notchy < Formula
  desc "Music, Claude Code, calendar and notifications in the MacBook notch"
  homepage "https://github.com/lleonardo-franco/notchy"
  url "https://github.com/lleonardo-franco/notchy/archive/refs/tags/v1.3.0.tar.gz"
  sha256 "c4369ff77df0697d2881f9e752267c94bf7c9c9856a385f1a1a224c3f204aa9b"
  license "MIT"
  head "https://github.com/lleonardo-franco/notchy.git", branch: "main"

  depends_on macos: :sonoma

  def install
    libexec.install Dir["*"]
    bin.env_script_all_files libexec/"bin", NOTCHY_SOURCE: opt_libexec.to_s, NOTCHY_HOMEBREW: "1"
  end

  def caveats
    <<~EOS
      Build Notchy and install it in /Applications with:
        notchy setup

      Run it again after every `brew upgrade notchy`.
    EOS
  end

  test do
    assert_match "notchy", shell_output("#{bin}/notchy help")
  end
end
