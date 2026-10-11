#!/usr/bin/env python3
"""Render an offline review gallery of native presentation fixtures, without input switching."""
import argparse
import html
import os
from pathlib import Path
import subprocess

ROOT = Path(__file__).resolve().parents[1]
FIXTURES = ('pinned', 'paused', 'secure', 'unavailable', 'retrying', 'unconfirmed',
            'restoring', 'session', 'approval', 'long-name', 'contrast')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--app', type=Path, default=ROOT/'build/InputPin.app')
    parser.add_argument('--output', type=Path, default=ROOT/'build/quality/panels')
    args = parser.parse_args()
    executable = args.app.resolve()/'Contents/MacOS/InputPin'
    if not executable.is_file():
        parser.error('Build the app with bash build.sh first')
    output = args.output.resolve()
    output.mkdir(parents=True, exist_ok=True)
    figures = []
    for locale in ('en', 'zh-Hans'):
        for appearance in ('light', 'dark'):
            for fixture in FIXTURES:
                name = f'{locale}-{appearance}-{fixture}.png'
                subprocess.run([str(executable), '--render-panel', str(output/name), appearance, fixture],
                               env={**os.environ, 'INPUTPIN_RENDER_LOCALE': locale}, check=True,
                               stdout=subprocess.DEVNULL)
                label = html.escape(f'{locale} · {appearance} · {fixture}')
                figures.append(f'<figure><figcaption>{label}</figcaption>'
                               f'<img src="{name}" alt="{label}" width="252"></figure>')
    page = '''<!doctype html><html lang="en"><meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1"><title>InputPin native review</title>
<style>body{font:14px system-ui;margin:24px;background:#e8e8e8;color:#222}
main{display:grid;grid-template-columns:repeat(auto-fit,minmax(276px,1fr));gap:20px}
figure{margin:0}figcaption{margin-bottom:10px}img{display:block;height:auto}</style>
<h1>InputPin native panel review</h1>
<p>Deterministic presentation fixtures with an opaque material. These are not live screenshots,
source-restoration tests, or proof of system accessibility settings.</p><main>'''
    (output/'index.html').write_text(page + ''.join(figures) + '</main></html>', encoding='utf-8')
    print(f'Rendered {len(figures)} native fixtures: {output/"index.html"}')


if __name__ == '__main__':
    main()
