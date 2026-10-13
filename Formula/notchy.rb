class Notchy < Formula
  desc "Music, Claude Code, calendar and notifications in the MacBook notch"
  homepage "https://github.com/lleonardo-franco/notchy"
  url "https://github.com/lleonardo-franco/notchy/archive/refs/tags/v1.2.0.tar.gz"
  sha256 "e8afc92af83191309f4a1c31dea8e8073f8ae3385bcc32d664fdb80c92d55b1e"
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
