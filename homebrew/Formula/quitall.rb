class Quitall < Formula
  desc "Quit every open app in one click, except the ones you pick (macOS menu bar app + CLI)"
  homepage "https://github.com/jdevesablanco/QuitAll"
  url "https://github.com/jdevesablanco/QuitAll/archive/refs/tags/v1.0.1.tar.gz"
  sha256 "5c0b4f2a9bf5b75002837a3144dba97076900ed6866d453669be9f0b37bdb71c"
  license "MIT"
  head "https://github.com/jdevesablanco/QuitAll.git", branch: "main"

  depends_on macos: :ventura

  def install
    # Se compila en tu Mac con las Command Line Tools: no hay descarga binaria, así que Gatekeeper no pone pegas.
    ENV["QUITALL_NO_SANDBOX"] = "1"
    ENV["VERSION"] = version.to_s
    system "Scripts/build-app.sh"
    prefix.install "build/QuitAll.app"
    bin.install_symlink prefix/"QuitAll.app/Contents/Resources/quitall"
  end

  def caveats
    <<~EOS
      QuitAll.app has been built locally. To copy it to /Applications and open it (first-run setup):
        quitall install
      Run `quitall install` again after each `brew upgrade quitall`.
    EOS
  end

  test do
    system bin/"quitall", "selftest"
  end
end
