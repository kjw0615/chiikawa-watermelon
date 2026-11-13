"""Mechanical atlas slicing/packing only; no drawing or background removal.

Run from repository root: python assets/source/item_effects_v1/export.py
Requires Pillow. Generated master PNG alpha is preserved.
"""
from pathlib import Path
import hashlib
import json
from PIL import Image

ROOT = Path(__file__).resolve().parents[3]
SOURCE = Path(__file__).resolve().parent
FOOD = ROOT / 'godot/assets/effects/food'
SHEETS = ROOT / 'godot/assets/effects/spritesheets'
JOBS = [('usagi_shake', 10, True), ('bazaar_ticket', 12, False), ('rakko_slash', 12, False)]


def write_json(path, value):
    path.write_text(json.dumps(value, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')


def main():
    FOOD.mkdir(parents=True, exist_ok=True)
    SHEETS.mkdir(parents=True, exist_ok=True)
    original = Image.open(SOURCE / 'masters/food-nine-draft-sheet.png').convert('RGBA')
    assert original.size == (576, 64)
    food_frames = []
    for i in range(9):
        name = f'food_{i+1:02}.png'
        tile = original.crop((i*64, 0, (i+1)*64, 64))
        tile.save(FOOD / name)
        assert Image.open(FOOD / name).tobytes() == tile.tobytes()
        food_frames.append({'file': name, 'source_rect': [i*64, 0, 64, 64]})
    write_json(FOOD / 'manifest.json', {
        'source': 'art/drafts/food_nine_v1/food-nine-draft-sheet.png',
        'archived_source': 'assets/source/item_effects_v1/masters/food-nine-draft-sheet.png',
        'frame_size': [64, 64], 'order': 'left-to-right',
        'alpha': 'preserved from original', 'frames': food_frames})

    audit = []
    for name, fps, loop in JOBS:
        master = Image.open(SOURCE / f'masters/{name}.png').convert('RGBA')
        assert master.width % 3 == 0 and master.height % 2 == 0
        sw, sh = master.width // 3, master.height // 2
        assert sw == sh, 'Master cells must be square; do not distort character poses'
        atlas = Image.new('RGBA', (768, 512))
        frames = []
        durations = [1000 / fps] * 6
        if name == 'bazaar_ticket':
            durations = [80, 120, 80, 70, 100, 180]
        elif name == 'rakko_slash':
            durations = [140, 70, 80, 50, 100, 160]
        for i in range(6):
            col, row = i % 3, i // 3
            frame = master.crop((col*sw, row*sh, (col+1)*sw, (row+1)*sh))
            frame = frame.resize((256, 256), Image.Resampling.LANCZOS)
            # Fixed cells and common pivot: never independently trim or re-center poses.
            atlas.paste(frame, (col*256, row*256))
            alpha = frame.getchannel('A')
            assert alpha.getextrema()[0] == 0 and alpha.getextrema()[1] > 200
            substantial = alpha.point(lambda a: 255 if a > 32 else 0).getbbox()
            assert substantial and substantial[0] > 0 and substantial[1] > 0
            assert substantial[2] < 256 and substantial[3] < 256, (name, i, substantial)
            frames.append({'index': i, 'rect': [col*256, row*256, 256, 256],
                           'duration_ms': round(durations[i], 3)})
        atlas.save(SHEETS / f'{name}.png')
        write_json(SHEETS / f'{name}.json', {
            'texture': f'{name}.png', 'frame_width': 256, 'frame_height': 256,
            'frame_count': 6, 'columns': 3, 'rows': 2, 'hframes': 3, 'vframes': 2,
            'order': 'row-major', 'fps': fps, 'loop': loop,
            'pivot_px': [128, 240], 'filter': 'linear',
            'godot_note': 'Set Sprite2D hframes=3,vframes=2; frame 0..5. JSON timing is descriptive, not auto-imported.',
            'frames': frames})
        audit.append({'file': f'{name}.png', 'size': list(atlas.size),
                      'alpha_range': atlas.getchannel('A').getextrema(),
                      'sha256': hashlib.sha256((SHEETS / f'{name}.png').read_bytes()).hexdigest(),
                      'validated_frames': 6})
    write_json(SOURCE / 'validation.json', {'food_exact_pixel_matches': 9, 'sheets': audit})
    print('Validated: 9 exact food crops; 3 RGBA atlases; 18 unclipped uniform frames.')


if __name__ == '__main__':
    main()
