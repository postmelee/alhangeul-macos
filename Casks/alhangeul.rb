cask "alhangeul" do
  version "0.2.4"
  sha256 "58868d2e1a2d85cdb7958e7ca470525fd4bcc7eb456342e5418ba4af9046a749"

  url "https://github.com/postmelee/alhangeul-macos/releases/download/v#{version}/alhangeul-macos-#{version}.dmg"
  name "알한글"
  desc "Quick Look, thumbnail, and viewer app for HWP/HWPX documents"
  homepage "https://github.com/postmelee/alhangeul-macos"

  depends_on macos: :monterey

  app "Alhangeul.app"

  caveats "앱을 한 번 실행한 뒤 Spotlight 색인과 미리보기 준비에 시간이 걸릴 수 있습니다."
end
