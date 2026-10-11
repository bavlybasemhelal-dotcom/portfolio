"""Export the repository's geometric YOGEN launcher mark to PNG icon sizes."""
import pathlib
from PIL import Image, ImageDraw

root = pathlib.Path(__file__).resolve().parents[1]
scale = 16
icon = Image.new('RGB', (108 * scale, 108 * scale), '#081120')
draw = ImageDraw.Draw(icon)
def face(points, color):
    draw.polygon([(round(x * scale), round(y * scale)) for x, y in points], fill=color)
face([(25,25),(50,40),(44,48),(25,37)], '#12c6eb')
outline = [(80,23),(80,36),(56,51),(56,75),(73,64),(73,60),(63,60),(63,52),(83,52),(83,70),(51,88),(44,81),(44,53)]
for step in range(1, 21):
    t = step / 20
    outline.append(((1-t)**2*44 + 2*(1-t)*t*44 + t*t*54,
                    (1-t)**2*53 + 2*(1-t)*t*45 + t*t*40))
face(outline, '#1678f5')
face([(44,65),(56,57),(56,75),(73,64),(83,70),(51,88),(44,81)], '#1744a3')
for file, size in [('Icon-192.png',192),('Icon-512.png',512),('Icon-maskable-192.png',192),('Icon-maskable-512.png',512)]:
    icon.resize((size,size), Image.Resampling.LANCZOS).save(root/'web/icons'/file)
icon.resize((64,64), Image.Resampling.LANCZOS).save(root/'web/favicon.png')
print('Exported YOGEN launcher assets from native vector geometry; no application tests run.')
