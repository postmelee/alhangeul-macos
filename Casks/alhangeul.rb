cask "alhangeul" do
  version "0.1.9"
  sha256 "8110dc4cc2d965b4fe4d0a8cd6b285488a1fb5443f5bda606a35207c5bccc6ca"

  url "https://github.com/postmelee/alhangeul-macos/releases/download/v#{version}/alhangeul-macos-#{version}.dmg"
  name "알한글"
  desc "Quick Look, thumbnail, and viewer app for HWP/HWPX documents"
  homepage "https://github.com/postmelee/alhangeul-macos"

  depends_on macos: :monterey

  app "Alhangeul.app"

  caveats "앱을 한 번 실행하면 Quick Look 및 Thumbnail 확장이 등록됩니다."
end
