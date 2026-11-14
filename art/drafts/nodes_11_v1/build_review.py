"""Measure unmodified draft PNGs and assemble a labeled review contact sheet.

Requires Pillow. This does not edit or replace any individual node artwork.
"""
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont
import hashlib
import html
import json

ROOT = Path(__file__).resolve().parent
REPO = ROOT.parents[2]
records = json.loads((ROOT / 'generation.json').read_text(encoding='utf-8'))['nodes']
font_path = Path('C:/Windows/Fonts/malgun.ttf')
font = ImageFont.truetype(str(font_path), 23) if font_path.exists() else ImageFont.load_default(size=23)
small = ImageFont.truetype(str(font_path), 17) if font_path.exists() else ImageFont.load_default(size=17)
title_font = ImageFont.truetype(str(font_path), 34) if font_path.exists() else font
board = Image.new('RGB', (2400, 1710), '#eef0f5')
d = ImageDraw.Draw(board)
d.text((40, 18), '11단계 노드 머리 시안 v1', font=title_font, fill='#232b40')
d.text((42, 66), '사용자 검수 대기 · 게임 미적용 | 각 칸: 기존 이미지(왼쪽 위) + 생성 머리 시안', font=font, fill='#814560')
manifest = {'status': 'draft_pending_user_review', 'approved': False, 'game_applied': False,
            'legacy_order': ['h', 'g', 'i', 'e', 'f', 'd', 'j', 'b', 'a', 'c', 'k'], 'images': []}
cards = []
for i, n in enumerate(records):
    assert n['stage'] == i + 1 and n['key'] == manifest['legacy_order'][i]
    p = ROOT / n['file']
    im = Image.open(p)
    assert im.mode == 'RGBA', (p, im.mode)
    alpha = im.getchannel('A')
    assert alpha.getextrema() == (0, 255), p
    box = alpha.point(lambda v: 255 if v >= 128 else 0).getbbox()
    assert box and box[0] > 0 and box[1] > 0 and box[2] < im.width and box[3] < im.height, (p, box)
    manifest['images'].append({'stage': n['stage'], 'key': n['key'], 'id': n['id'], 'file': n['file'],
        'size': list(im.size), 'mode': im.mode, 'alpha_range': list(alpha.getextrema()),
        'bbox_alpha_128': list(box), 'bytes': p.stat().st_size,
        'sha256': hashlib.sha256(p.read_bytes()).hexdigest()})
    x, y = (i % 4) * 600 + 15, 120 + (i // 4) * 525
    d.rounded_rectangle((x, y, x + 570, y + 505), radius=18, fill='white')
    d.text((x + 18, y + 12), f"{n['stage']:02d}  {n['name']}  /  {n['key']}", font=font, fill='#293149')
    legacy = REPO / n['legacy']
    # The SVG reference is rendered by the browser in review.html; the board
    # uses a Godot rasterization of that same existing repository asset.
    ref = legacy if legacy.suffix.lower() != '.svg' else ROOT / 'reference/legacy_k.png'
    if ref.exists():
        thumb = Image.open(ref).convert('RGBA')
        thumb.thumbnail((94, 94))
        board.paste(thumb, (x + 18, y + 58), thumb)
    d.text((x + 18, y + 155), '기존', font=small, fill='#68728b')
    thumb = im.copy()
    thumb.thumbnail((410, 360))
    board.paste(thumb, (x + 135 + (410 - thumb.width) // 2, y + 60 + (360 - thumb.height) // 2), thumb)
    d.text((x + 18, y + 447), 'DRAFT · 사용자 확인 전 적용 금지', font=small, fill='#a74a69')
    esc = html.escape
    cards.append(f'''<article id="node-{n['stage']}"><header><b>{n['stage']:02d} · {esc(n['name'])}</b><span>기존 {n['key']}</span></header>
    <div class="compare"><figure class="legacy"><img src="../../../{n['legacy']}" alt="{n['stage']}단계 기존 이미지"><figcaption>기존 이미지</figcaption></figure>
    <a class="draft" href="{n['file']}" target="_blank"><img src="{n['file']}" alt="{esc(n['name'])} 머리 시안"><span>시안 원본 확대 ↗</span></a></div>
    <p>{esc(n['review_focus'])}</p><a class="source" href="{n['official_page']}" target="_blank">공식 대조 자료 ↗</a>
    <div class="status">미승인 · 사용자 검수 대기</div></article>''')
d.rounded_rectangle((1815, 1170, 2385, 1675), radius=18, fill='#e2e6ef')
for j, line in enumerate(['검수 포인트', '① 순서·노드 이름', '② 귀·눈·입·볼·색·장식', '③ 우사기의 원작 인상', '④ 2.5D 깊이·외곽선', '⑤ 세이렌 머리 위 인어 둘', '', '통과 후 별도 게임 적용']):
    d.text((1840, 1200 + j * 46), line, font=font, fill='#35425c')
board.save(ROOT / 'review_board.png')
(ROOT / 'manifest.json').write_text(json.dumps(manifest, ensure_ascii=False, indent=2), encoding='utf-8')
page = '''<!doctype html><html lang="ko"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>11단계 노드 머리 시안 · 검수 대기</title><style>
*{box-sizing:border-box}body{margin:0;padding:32px;background:#eef0f5;color:#293149;font:16px/1.65 'Malgun Gothic',sans-serif}main{max-width:1500px;margin:auto}h1{margin:0;font-size:30px}.notice{background:#fff0f4;border-left:5px solid #ba587c;padding:14px 20px;border-radius:8px}.grid{display:grid;grid-template-columns:repeat(3,minmax(0,1fr));gap:20px;margin-top:24px}article{background:white;border-radius:16px;padding:20px;min-width:0}header{display:flex;justify-content:space-between;gap:10px}header span,.source{font-size:13px;color:#66748c}.compare{display:flex;align-items:flex-start;height:300px;gap:8px;margin-top:14px;background:repeating-conic-gradient(#f4f5f8 0% 25%,#fff 0% 50%) 50%/24px 24px;border-radius:10px;padding:10px}.legacy{margin:0;width:72px;flex-shrink:0;font-size:11px;color:#66748c;text-align:center}.legacy img{width:100%;height:80px;object-fit:contain}.draft{display:flex;flex-direction:column;align-items:center;justify-content:center;flex:1;min-width:0;height:100%;text-decoration:none;font-size:12px}.draft img{width:100%;height:250px;object-fit:contain}.draft span{color:#6b527b}p{font-size:14px}.status{margin-top:14px;color:#a54468;font-size:12px}a{color:#655087}nav a{display:inline-block;padding:8px 12px;background:white;border-radius:8px;margin:8px 4px 0 0}.checks{margin-top:30px;background:white;padding:24px;border-radius:16px}.checks label{display:block}footer{margin:32px 0;color:#66748c;font-size:13px}@media(max-width:1100px){.grid{grid-template-columns:repeat(2,minmax(0,1fr))}}@media(max-width:650px){body{padding:16px}.grid{grid-template-columns:1fr}}
</style><main><h1>11단계 노드 머리 시안 v1</h1>
<p class="notice"><b>사용자 검수 대기 · 게임 미적용</b><br>원작 식별 특징을 확인하는 시안입니다. 단계별 이름·귀·눈·입·볼·색·장식과 2.5D 깊이를 검수해 주세요. 이미지 클릭으로 원본을 확대할 수 있습니다.</p>
<nav><a href="review_board.png">11종 한눈 비교</a><a href="README.md">조사·제작 기준</a><a href="https://github.com/kjw0615/chiikawa-watermelon/issues/1">Issue #1</a></nav>
<div class="grid">''' + ''.join(cards) + '''</div><section class="checks"><b>검수 기록 안내</b><p>검수 결과는 단계 번호와 수정할 부위를 함께 기록해 전달합니다. 우사기의 원작 인상, 9=아노코·10=데카츠요 대응, 세이렌의 머리 위 인어 둘 포함 여부를 특히 확인합니다. 이 페이지는 승인 상태를 저장하거나 게임에 적용하는 기능이 없습니다.</p></section>
<footer>내장 image_gen 생성 · 원본 PNG 보존 · 사용자 통과 후 별도 적용 · 원작 도안과 완벽히 일치하는 정식 디자인 가이드는 아닙니다.</footer></main></html>'''
(ROOT / 'review.html').write_text(page, encoding='utf-8')
print(f'Validated {len(records)} RGBA drafts; review_board.png, review.html, manifest.json written.')
