#!/usr/bin/env python3
"""Fail if any internal href/src on the landing page does not resolve.

Checks the pages in web/. Used by .github/workflows/deploy-web.yml to stop a
broken link reaching the published site. Lives outside web/ so it is not itself
published as a static asset.
"""
import os, re, sys

web = os.path.join(os.path.dirname(os.path.abspath(__file__)), os.pardir, 'web')
os.chdir(web)

problems = []
pages = sorted(f for f in os.listdir('.') if f.endswith('.html'))
if not pages:
    sys.exit("no HTML pages found in web/")

for page in pages:
    html = open(page, encoding='utf-8').read()
    for attr, link in re.findall(r'(href|src)="([^"]+)"', html):
        if link.startswith(('http://', 'https://', 'mailto:', 'data:', '#')):
            continue
        target = link.split('#')[0].split('?')[0].lstrip('/')  # root-relative = web/ root
        if target in ('', './'):
            target = 'index.html'
        if not os.path.exists(target):
            problems.append(f"{page}: {attr}=\"{link}\" -> missing {target}")

for p in problems:
    print(f"::error file=web/{p.split(':')[0]}::broken internal link: {p}")
print(f"checked {len(pages)} page(s): {', '.join(pages)}")
if problems:
    sys.exit(f"{len(problems)} broken internal link(s)")
print("all internal links resolve")
