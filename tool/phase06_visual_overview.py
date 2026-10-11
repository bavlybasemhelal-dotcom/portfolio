"""Local QA contact sheet; does not alter product assets."""
from pathlib import Path
from PIL import Image, ImageDraw

root = Path(__file__).resolve().parent.parent
shots = root / 'phases/results/06/screenshots'
routes = ['home', 'work', 'project', 'services', 'about', 'contact']
groups = [('ar', 'dark', 1440), ('en', 'light', 360), ('ar', 'light', 768)]
canvas = Image.new('RGB', (1200, 2040), '#eeeeee')
draw = ImageDraw.Draw(canvas)
for row, route in enumerate(routes):
    for col, (lang, theme, width) in enumerate(groups):
        src = shots / f'{route}-{lang}-{theme}-{width}.png'
        picture = Image.open(src).convert('RGB')
        picture.thumbnail((390, 305))
        x, y = col * 400, row * 340
        draw.text((x + 8, y + 5), src.stem, fill='#000000')
        canvas.paste(picture, (x + (400-picture.width)//2, y+28))
canvas.save(root / '.runtime/phase06-visual-overview.jpg', quality=90)
