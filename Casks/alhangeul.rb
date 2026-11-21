cask "alhangeul" do
  version "0.2.5"
  sha256 "e6ad65f64fc27a15e4e03ae19a5c8155f09ec33b539b2d17b88fe057afdc2f52"

  url "https://github.com/postmelee/alhangeul-macos/releases/download/v#{version}/alhangeul-macos-#{version}.dmg"
  name "알한글"
  desc "Quick Look, thumbnail, and viewer app for HWP/HWPX documents"
  homepage "https://github.com/postmelee/alhangeul-macos"

  depends_on macos: :monterey

  app "Alhangeul.app"

  caveats "앱을 한 번 실행한 뒤 Spotlight 색인과 미리보기 준비에 시간이 걸릴 수 있습니다."
end
