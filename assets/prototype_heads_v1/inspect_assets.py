"""Read-only sprite measurements and an explicitly labeled QA contact sheet."""
import json
import hashlib
from pathlib import Path
from PIL import Image, ImageDraw

ROOT = Path(__file__).parent
CHARACTERS = ['chiikawa', 'hachiware', 'usagi']
STATES = ['neutral', 'surprised', 'squash', 'happy']
manifest = {'version': 1, 'mode': 'built-in image_gen', 'images': {}, 'warnings': []}
sheet = Image.new('RGB', (1200, 900), '#b7bbc6')
draw = ImageDraw.Draw(sheet)
for row, character in enumerate(CHARACTERS):
    records = {}
    base = Image.open(ROOT / character / 'neutral.png').convert('RGBA')
    base_mask = base.getchannel('A').point(lambda v: 255 if v >= 128 else 0)
    bb = base_mask.getbbox()
    head_y_fraction = 0.77 if character == 'usagi' else 0.61
    pivot = [(bb[0] + bb[2]) / 2, bb[1] + (bb[3] - bb[1]) * head_y_fraction]
    for col, state in enumerate(STATES):
        p = ROOT / character / (state + '.png')
        if not p.exists():
            manifest['warnings'].append(str(p.relative_to(ROOT)) + ' missing')
            continue
        im = Image.open(p)
        alpha = im.getchannel('A')
        mask = alpha.point(lambda v: 255 if v >= 128 else 0)
        box = mask.getbbox()
        rec = {'file': str(p.relative_to(ROOT)).replace('\\', '/'), 'size': list(im.size), 'mode': im.mode,
               'alpha_range': list(alpha.getextrema()), 'bbox_alpha_128': list(box),
               'transparent_fraction': round(alpha.histogram()[0] / (im.width * im.height), 4),
               'sha256': hashlib.sha256(p.read_bytes()).hexdigest()}
        if im.size == base.size:
            aa, ba = mask.tobytes(), base_mask.tobytes()
            union = sum(bool(x) or bool(y) for x, y in zip(aa, ba))
            inter = sum(bool(x) and bool(y) for x, y in zip(aa, ba))
            rec['silhouette_iou_vs_neutral'] = round(inter / union, 4)
        else:
            manifest['warnings'].append(character + '/' + state + ': canvas differs from neutral; per-state display adjustment required')
        records[state] = rec
        thumb = im.copy()
        thumb.thumbnail((270, 250))
        x = col * 300 + (300 - thumb.width) // 2
        y = row * 300 + 35 + (250 - thumb.height) // 2
        sheet.paste(thumb, (x, y), thumb)
        draw.text((col * 300 + 12, row * 300 + 10), character + ' / ' + state, fill='#18202e')
    manifest['images'][character] = {'suggested_neutral_pivot_px': pivot, 'states': records}
(ROOT / 'manifest.json').write_text(json.dumps(manifest, ensure_ascii=False, indent=2), encoding='utf-8')
sheet.save(ROOT / 'review_contact.png')
print(json.dumps(manifest, ensure_ascii=True, indent=2))
