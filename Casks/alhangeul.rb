cask "alhangeul" do
  version "0.1.2"
  sha256 "37a27321f03a84b8b28749b5f839ea5c5833975d20f2479e3b79ebd665811ead"

  url "https://github.com/postmelee/alhangeul-macos/releases/download/v#{version}/alhangeul-macos-#{version}.dmg"
  name "알한글"
  desc "Quick Look, thumbnail, and viewer app for HWP/HWPX documents"
  homepage "https://github.com/postmelee/alhangeul-macos"

  depends_on macos: :monterey

  app "Alhangeul.app"

  caveats "앱을 한 번 실행하면 Quick Look 및 Thumbnail 확장이 등록됩니다."
end
