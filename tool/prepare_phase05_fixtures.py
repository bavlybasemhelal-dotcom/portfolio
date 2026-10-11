"""Generate format/geometry fixtures; these are labeled tests, never portfolio work."""
import io
import json
from pathlib import Path
from PIL import Image, ImageDraw

root = Path(__file__).resolve().parent.parent
folder = root / 'assets/fixtures/phase05'
folder.mkdir(parents=True, exist_ok=True)
report = []
for name, width, height, format in [('صورة-أفقية.png',800,450,'PNG'),
    ('صورة-رأسية.jpg',450,800,'JPEG'), ('صورة-ويب.webp',640,480,'WEBP')]:
    image = Image.new('RGB',(width,height),(12,26,50))
    draw=ImageDraw.Draw(image)
    for index in range(0,width,20):
        draw.rectangle((index,0,index+19,height),fill=(12+(index*25//width),75+(index*70//width),150+(index*80//width)))
    draw.rectangle((width//6,height//6,width*5//6,height*5//6),outline=(85,215,237),width=8)
    draw.text((width//6+20,height//6+20),'YOGEN MEDIA TEST',(255,255,255))
    output=folder/name; image.save(output,format=format)
    thumb=image.copy(); thumb.thumbnail((320,320)); stream=io.BytesIO(); thumb.save(stream,format='PNG')
    (folder/(name+'.thumbnail.png')).write_bytes(stream.getvalue())
    report.append({'name':name,'bytes':output.stat().st_size,'width':width,'height':height,'thumbnailBytes':len(stream.getvalue())})

# A complete, minimal one-page PDF with valid cross-reference offsets.
pdf_stream = b'BT /F1 18 Tf 30 100 Td (YOGEN MEDIA TEST PDF) Tj ET\n'
objects = [b'<< /Type /Catalog /Pages 2 0 R >>', b'<< /Type /Pages /Kids [3 0 R] /Count 1 >>',
  b'<< /Type /Page /Parent 2 0 R /MediaBox [0 0 300 200] /Resources << /Font << /F1 5 0 R >> >> /Contents 4 0 R >>',
  f'<< /Length {len(pdf_stream)} >>\nstream\n'.encode() + pdf_stream + b'endstream',
  b'<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica >>']
content=bytearray(b'%PDF-1.4\n'); offsets=[0]
for number,obj in enumerate(objects,1):
    offsets.append(len(content)); content.extend(str(number).encode()+b' 0 obj\n'+obj+b'\nendobj\n')
xref=len(content); content.extend(b'xref\n0 6\n0000000000 65535 f \n')
for offset in offsets[1:]: content.extend(f'{offset:010} 00000 n \n'.encode())
content.extend(f'trailer\n<< /Size 6 /Root 1 0 R >>\nstartxref\n{xref}\n%%EOF\n'.encode())
(folder/'مرفق-اختبار.pdf').write_bytes(content)
(folder/'نوع-مرفوض.html').write_text('<p>Not an allowed media file</p>',encoding='utf-8')
report.append({'name':'مرفق-اختبار.pdf','bytes':len(content)})
(root/'phases/results/05/checks/fixtures.json').write_text(json.dumps(report,ensure_ascii=False,indent=2),encoding='utf-8')
print(json.dumps({'generatedImages':3,'generatedPDF':1}))
