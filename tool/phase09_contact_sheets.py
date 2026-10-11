"""Assemble browser QA captures for visual inspection; no browser automation."""
import pathlib
from PIL import Image, ImageDraw

root = pathlib.Path(__file__).resolve().parents[1] / 'phases/results/09/screenshots'
routes = ['home', 'work', 'detail', 'services', 'about', 'contact']
columns = [('ar', 'dark'), ('ar', 'light'), ('en', 'dark'), ('en', 'light')]
for width, thumb in [(360, 180), (768, 260), (1440, 360)]:
    height = round((850 if width == 360 else 900) * thumb / width)
    for group in [0, 1]:
        sheet = Image.new('RGB', (4 * thumb, 3 * (height + 26)), '#eeeeee')
        draw = ImageDraw.Draw(sheet)
        for row, route in enumerate(routes[group * 3:group * 3 + 3]):
            for col, (lang, theme) in enumerate(columns):
                name = f'{width}-{lang}-{theme}-{route}.jpg'
                capture = Image.open(root / 'matrix-final' / name)
                assert capture.size == (width, 850 if width == 360 else 900)
                sheet.paste(capture.resize((thumb, height)), (col * thumb, row * (height + 26) + 26))
                draw.text((col * thumb + 3, row * (height + 26) + 5), f'{width} {lang} {theme} {route}', fill='#111111')
        sheet.save(root / f'review-{width}-{group}.jpg', quality=92)
print('6 review sheets saved')
