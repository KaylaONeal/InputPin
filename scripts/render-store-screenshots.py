#!/usr/bin/env python3
"""Export three localized store images from native controls, without input switching."""
import argparse
import hashlib
import html
import json
import os
from pathlib import Path
import shutil
import struct
import subprocess

ROOT = Path(__file__).resolve().parents[1]
PAGES = ('01-pin', '02-choose', '03-pause')
TITLES = {
    'en-US': ('Pin your chosen input method.', 'Choose it. Pin it. Keep typing.',
              'Pause pinning. Switch freely.'),
    'zh-Hans': ('固定你指定的输入法', '选好输入法，开启固定', '需要切换，随时暂停'),
}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--app', type=Path, default=ROOT/'build/InputPin.app')
    parser.add_argument('--output', type=Path, default=ROOT/'build/store-screenshots')
    parser.add_argument('--hero-image', type=Path, help='Use supplied artwork as the first English image')
    args = parser.parse_args()
    executable = args.app.resolve()/'Contents/MacOS/InputPin'
    if not executable.is_file():
        parser.error('Build InputPin first, or supply --app /path/to/InputPin.app')
    output = args.output.resolve()
    output.mkdir(parents=True, exist_ok=True)
    assets, sections = [], []
    for locale in TITLES:
        directory = output/locale
        directory.mkdir(exist_ok=True)
        figures = []
        for page, name in enumerate(PAGES, 1):
            path = directory/(name+'.png')
            provided = locale == 'en-US' and page == 1 and args.hero_image is not None
            if provided:
                shutil.copyfile(args.hero_image, path)
            else:
                subprocess.run([str(executable), '--render-store', str(path), str(page)],
                               env={**os.environ, 'INPUTPIN_RENDER_LOCALE': locale}, check=True,
                               stdout=subprocess.DEVNULL)
            raw = path.read_bytes()
            dimensions = struct.unpack('>II', raw[16:24]) if len(raw) >= 33 else (0, 0)
            accepted = {(1280, 800), (1440, 900), (2560, 1600), (2880, 1800)} if provided else {(2560, 1600)}
            if (raw[:8] != b'\x89PNG\r\n\x1a\n' or dimensions not in accepted
                    or raw[24:26] != bytes([8, 2])):
                raise SystemExit(f'Expected an opaque RGB PNG in a supported Mac size: {path.name}')
            assets.append({'locale': locale, 'page': page, 'file': str(path.relative_to(output)),
                           'kind': 'provided-artwork' if provided else 'native-presentation-fixture',
                           'sha256': hashlib.sha256(raw).hexdigest(), 'width': dimensions[0], 'height': dimensions[1]})
            title = html.escape(TITLES[locale][page-1])
            figures.append(f'<figure><a href="{locale}/{path.name}"><img src="{locale}/{path.name}" '
                           f'alt="{title}" width="1280" height="800"></a><figcaption>{page}. {title}</figcaption></figure>')
        sections.append(f'<section><h2>{locale}</h2><div class="images">'+''.join(figures)+'</div></section>')
    (output/'manifest.json').write_text(json.dumps({'version': (ROOT/'VERSION').read_text().strip(),
        'assets': assets}, ensure_ascii=False, indent=2)+'\n')
    (output/'index.html').write_text('''<!doctype html><html lang="zh-Hans"><meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1"><title>InputPin 商店截图</title>
<style>body{font:15px system-ui;margin:32px;background:#f2f5f8;color:#142c40}
h1{font-size:28px}.images{display:grid;grid-template-columns:repeat(auto-fit,minmax(320px,1fr));gap:20px}
figure{margin:0}img{display:block;width:100%;height:auto;border-radius:12px}figcaption{margin:12px 0 24px}
a:focus-visible{outline:3px solid #006cc0}</style><h1>InputPin — 输入法固定</h1>
<p>三张截图：固定指定输入法 → 选择并开启 → 暂停后自由切换。点击图片查看原尺寸。</p>
<p>原生控件示例状态与提供的商店图片；外围显示器画面为示意。此页用于查看素材，不代表上传或审核状态。</p>
'''+''.join(sections)+'</html>', encoding='utf-8')
    print(f'Prepared 6 opaque Mac store images: {output/"index.html"}')


if __name__ == '__main__':
    main()
