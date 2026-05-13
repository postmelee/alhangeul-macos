cask "alhangeul-macos" do
  version "0.1.1"
  sha256 "12c5755fa0ac75dd13f813c6e65f0fc37a7e43e07080317c7df54b06e9c60e16"

  url "https://github.com/postmelee/alhangeul-macos/releases/download/v#{version}/alhangeul-macos-#{version}.dmg"
  name "알한글"
  desc "Quick Look, thumbnail, and viewer app for HWP/HWPX documents"
  homepage "https://github.com/postmelee/alhangeul-macos"

  depends_on macos: ">= :monterey"

  app "Alhangeul.app"

  caveats "앱을 한 번 실행하면 Quick Look 및 Thumbnail 확장이 등록됩니다."
end
