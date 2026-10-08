from pathlib import Path
import plistlib,subprocess,platform,shutil
root=Path('/Users/melee/Documents/projects/rhwp-mac')
out=root/'build.noindex/task567/pr7405-validation'
app=out/'FontProviderProbe.app'
exe=app/'Contents/MacOS/FontProviderProbe'
exe.parent.mkdir(parents=True,exist_ok=True)
resources=app/'Contents/Resources';resources.mkdir(exist_ok=True)
shutil.copytree(out/'upstream/probe-dist',resources/'rhwp-studio',dirs_exist_ok=True)
shutil.copyfile(resources/'rhwp-studio/probe.html',resources/'rhwp-studio/index.html')
(app/'Contents/Info.plist').write_bytes(plistlib.dumps({'CFBundleIdentifier':'com.postmelee.fontprovider.pr7405.probe','CFBundleExecutable':exe.name,'CFBundlePackageType':'APPL','NSHighResolutionCapable':True}))
sources=[p for d in ('Sources/HostApp','Sources/Shared','Sources/RhwpCoreBridge') for p in sorted((root/d).rglob('*.swift')) if p.name not in ('HostApp.swift','UpdateController.swift')]
bridge=root/'Frameworks/Rhwp.xcframework/macos-arm64_x86_64'
cmd=['xcrun','swiftc','-parse-as-library','-swift-version','5','-target',platform.machine()+'-apple-macosx12.0','-module-cache-path',str(out/'module-cache'),'-I',str(bridge/'Headers'),'-L',str(bridge),'-lrhwp','-lc++','-liconv','-lz']
for f in ('AppKit','WebKit','SwiftUI','CoreFoundation','CoreText','CoreGraphics','ImageIO','CoreServices','Network','ApplicationServices','Security','Metal','QuartzCore','IOSurface','ColorSync'):cmd+=['-framework',f]
cmd+=list(map(str,sources))+[str(out/'main.swift'),'-o',str(exe)]
with (out/'swift-build.log').open('w') as log:subprocess.run(cmd,stdout=log,stderr=subprocess.STDOUT,check=True,timeout=300)
print(exe)
