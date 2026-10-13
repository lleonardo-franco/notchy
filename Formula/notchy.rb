class Notchy < Formula
  desc "Music, Claude Code, calendar and notifications in the MacBook notch"
  homepage "https://github.com/lleonardo-franco/notchy"
  url "https://github.com/lleonardo-franco/notchy/archive/refs/tags/v1.1.0.tar.gz"
  sha256 "70e0322ec952807a5387db3534d5c6600a878a9c31117102caed6a22fff07625"
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
