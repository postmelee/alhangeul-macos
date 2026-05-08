cask "alhangeul-macos" do
  version "0.1.0"
  sha256 "98d4e1807dfece2acd08510441c0f1a41cad9a8f5bbe1b82cf9ed4d3abb0f3c4"

  url "https://github.com/postmelee/alhangeul-macos/releases/download/v#{version}/alhangeul-macos-#{version}.dmg"
  name "알한글"
  desc "Quick Look, thumbnail, and viewer app for HWP/HWPX documents"
  homepage "https://github.com/postmelee/alhangeul-macos"

  depends_on macos: ">= :monterey"

  app "Alhangeul.app"

  caveats "앱을 한 번 실행하면 Quick Look 및 Thumbnail 확장이 등록됩니다."
end
