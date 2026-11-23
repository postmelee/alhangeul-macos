cask "alhangeul" do
  version "0.2.8"
  sha256 "54aaa7d5007c8a53ba6f0062f6da5519c510dc5c91c92ac8f2f1961903d6f1ac"

  url "https://github.com/postmelee/alhangeul-macos/releases/download/v#{version}/alhangeul-macos-#{version}.dmg"
  name "알한글"
  desc "Quick Look, thumbnail, and viewer app for HWP/HWPX documents"
  homepage "https://github.com/postmelee/alhangeul-macos"

  depends_on macos: :monterey

  app "Alhangeul.app"

  caveats "앱을 한 번 실행한 뒤 Spotlight 색인과 미리보기 준비에 시간이 걸릴 수 있습니다."
end
