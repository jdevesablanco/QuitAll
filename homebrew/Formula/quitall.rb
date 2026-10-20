class Quitall < Formula
  desc "Quit every open app in one click, except the ones you pick (macOS menu bar app + CLI)"
  homepage "https://github.com/jdevesablanco/QuitAll"
  url "https://github.com/jdevesablanco/QuitAll/archive/refs/tags/v1.0.0.tar.gz"
  sha256 "b18046f5122691385519a38b843238751763bdfe4fc0665f2112f75a2cbf7c7f"
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
