#!/usr/bin/env python3
"""Write a SHA-256-pinned cask into a local checkout of the maintained tap."""
import hashlib
import re
import sys
from pathlib import Path

project = Path(__file__).resolve().parent.parent
version = (project / 'VERSION').read_text().strip()
if not re.fullmatch(r'[0-9]+\.[0-9]+\.[0-9]+', version):
    raise SystemExit('Invalid VERSION')
dmg = project / 'dist' / f'InputPin-{version}-universal.dmg'
checksum = hashlib.sha256(dmg.read_bytes()).hexdigest()
tap = Path(sys.argv[1]).resolve()
if not (tap / '.git').exists():
    raise SystemExit('Pass an existing local tap checkout')
(tap / 'Casks').mkdir(exist_ok=True)
cask = f'''cask "inputpin" do
  version "{version}"
  sha256 "{checksum}"

  url "https://github.com/KaylaONeal/InputPin/releases/download/v#{{version}}/InputPin-#{{version}}-universal.dmg",
      verified: "github.com/KaylaONeal/InputPin/"
  name "InputPin"
  desc "Keep your selected keyboard input source in place"
  homepage "https://kaylaoneal.github.io/InputPin/"

  depends_on macos: ">= :ventura"

  app "InputPin.app"
  binary "#{{appdir}}/InputPin.app/Contents/MacOS/InputPin", target: "inputpin"

  uninstall quit: "io.github.kaylaoneal.InputPin"

  zap trash: "~/Library/Preferences/io.github.kaylaoneal.InputPin.plist"
end
'''
(tap / 'Casks/inputpin.rb').write_text(cask)
print(f'Prepared cask for InputPin {version} with SHA-256 {checksum}')
