cask "alhangeul" do
  version "0.2.7"
  sha256 "67937459a5b9631e80d9e44459b332dc0c2a25d4f0685f2ce98fd7600539a965"

  url "https://github.com/postmelee/alhangeul-macos/releases/download/v#{version}/alhangeul-macos-#{version}.dmg"
  name "알한글"
  desc "Quick Look, thumbnail, and viewer app for HWP/HWPX documents"
  homepage "https://github.com/postmelee/alhangeul-macos"

  depends_on macos: :monterey

  app "Alhangeul.app"

  caveats "앱을 한 번 실행한 뒤 Spotlight 색인과 미리보기 준비에 시간이 걸릴 수 있습니다."
end
