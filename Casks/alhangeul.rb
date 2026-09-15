cask "alhangeul" do
  version "0.2.2"
  sha256 "8d8b8cbd24376fcd2c7ebd48343be44edc1f0f154a1e75282714798806ed4b90"

  url "https://github.com/postmelee/alhangeul-macos/releases/download/v#{version}/alhangeul-macos-#{version}.dmg"
  name "알한글"
  desc "Quick Look, thumbnail, and viewer app for HWP/HWPX documents"
  homepage "https://github.com/postmelee/alhangeul-macos"

  depends_on macos: :monterey

  app "Alhangeul.app"

  caveats "앱을 한 번 실행한 뒤 Spotlight 색인과 미리보기 준비에 시간이 걸릴 수 있습니다."
end
