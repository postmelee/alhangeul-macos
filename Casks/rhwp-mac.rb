cask "rhwp-mac" do
  version "0.1.0"
  sha256 :no_check

  url "https://github.com/postmelee/rhwp-mac/releases/download/v#{version}/rhwp-mac-#{version}.zip"
  name "rhwp-mac"
  desc "Quick Look, thumbnail, and viewer app for HWP/HWPX documents"
  homepage "https://github.com/postmelee/rhwp-mac"

  depends_on macos: ">= :monterey"

  app "RhwpMac.app"

  caveats "앱을 한 번 실행하면 Quick Look 및 Thumbnail 확장이 등록됩니다."
end
