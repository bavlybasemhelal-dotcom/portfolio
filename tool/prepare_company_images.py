"""Copy observed Notion images locally and create review sheets before selection."""
import json
from pathlib import Path
from PIL import Image, ImageOps, ImageDraw

ROOT = Path(__file__).resolve().parent.parent
CONTENT = ROOT / 'content/company-projects'
REVIEW = ROOT / '.runtime/company-content/images'
REVIEW.mkdir(parents=True, exist_ok=True)
for number in range(1, 16):
    code = f'P{number:03}'
    record = json.loads((CONTENT / f'source/{code}.json').read_text(encoding='utf-8'))
    assets = record['bundle']['assets'] if record.get('bundle') else []
    if number == 1:
        assets = json.loads((CONTENT / 'source/P001-sales-assets.json').read_text())['assets']
    dest = REVIEW / code
    dest.mkdir(exist_ok=True)
    rows = (len(assets)+2)//3
    sheet = Image.new('RGB', (1500, rows*310), '#e6e9ee')
    draw = ImageDraw.Draw(sheet)
    metadata = []
    for index, asset in enumerate(assets):
        image = Image.open(asset['path']).convert('RGB')
        image.save(dest / f'{index:02}.png')
        thumb = ImageOps.contain(image, (490, 275))
        x, y = index%3*500, index//3*310
        sheet.paste(thumb, (x+(500-thumb.width)//2,y+25))
        draw.text((x+10,y+5),f'{code} / {index:02} / {image.width}x{image.height}',fill='#111111')
        metadata.append({'index':index,'sourceUrl':asset['url'],'originalSize':[image.width,image.height]})
    sheet.save(REVIEW/f'{code}-sheet.jpg',quality=90)
    (dest/'source.json').write_text(json.dumps(metadata,indent=2),encoding='utf-8')
print(json.dumps({'projects':15,'reviewDirectory':str(REVIEW)}))
