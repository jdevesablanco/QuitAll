cask "quitall" do
  version "1.0.0"
  sha256 "REPLACE_WITH_DMG_SHA256"

  url "https://github.com/jdevesablanco/QuitAll/releases/download/v#{version}/QuitAll-#{version}.dmg"
  name "QuitAll"
  desc "Quit every open app in one click, except the ones you pick"
  homepage "https://github.com/jdevesablanco/QuitAll"

  depends_on macos: ">= :ventura"

  app "QuitAll.app"
  binary "#{appdir}/QuitAll.app/Contents/Resources/quitall"

  # La app no está notarizada (no hay cuenta de Apple Developer de pago): sin esto macOS la bloquearía al abrirla.
  postflight do
    system_command "/usr/bin/xattr", args: ["-dr", "com.apple.quarantine", "#{appdir}/QuitAll.app"]
  end

  uninstall quit: "com.jdevesablanco.quitall"
  zap trash: [
    "~/Library/Application Support/QuitAll",
    "~/Library/Services/QuitAll: cerrar todo.workflow",
    "~/Library/Services/QuitAll: Quit all.workflow",
  ]
end
