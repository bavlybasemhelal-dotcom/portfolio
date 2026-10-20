"""Prepare the user-provided team photos and bilingual public profiles."""
import argparse
import hashlib
import html
import json
from pathlib import Path
from PIL import Image, ImageOps

root = Path(__file__).resolve().parent.parent
parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--source-dir', type=Path, required=True)
args = parser.parse_args()
source = args.source_dir.resolve()
if not source.is_dir():
    parser.error('The source photo directory does not exist.')
out = root / 'content/company-team'
(out / 'images').mkdir(parents=True, exist_ok=True)
bi = lambda ar, en: {'ar': ar, 'en': en}
members = [
    {'id': 'george-mounir', 'source': 'م. جورج منير.jpg', 'phone': '01276169360',
     'name': bi('م. جورج منير', 'Eng. George Mounir'),
     'role': bi('مهندس تطبيقات سطح المكتب — C# · WPF · .NET',
                'Desktop Software Engineer — C# · WPF · .NET'),
     'bio': bi('متخصص في تطوير تطبيقات سطح المكتب باستخدام C# وWPF ومنظومة .NET. يجمع دوره بين بناء واجهات الاستخدام وتطوير وظائف التطبيقات لخدمة احتياجات الأعمال.',
               'Specializes in desktop application development with C#, WPF and .NET. His work connects user interfaces with application functionality to support business needs.')},
    {'id': 'youssab-wagdy', 'source': 'م. يوساب وجدي.png', 'phone': '01036976446',
     'name': bi('م. يوساب وجدي', 'Eng. Youssab Wagdy'),
     'role': bi('مهندس تطبيقات وخدمات خلفية — Flutter · Node.js',
                'App & Backend Engineer — Flutter · Node.js'),
     'bio': bi('يطوّر تطبيقات متعددة المنصات باستخدام Flutter وخدمات خلفية باستخدام Node.js. يجمع دوره بين تجربة الاستخدام وربط التطبيقات بالبيانات والخدمات.',
               'Develops cross-platform applications with Flutter and backend services with Node.js. His work connects the user experience with application data and services.')},
    {'id': 'bavly-basem', 'source': 'م. بافلي باسم.png', 'phone': '01227232991',
     'name': bi('م. بافلي باسم', 'Eng. Bavly Basem'),
     'role': bi('مهندس تطبيقات وخدمات خلفية — Flutter · Node.js',
                'App & Backend Engineer — Flutter · Node.js'),
     'bio': bi('يعمل على تطوير واجهات التطبيقات بـFlutter وخدمات النظام بـNode.js. يساهم في تحويل متطلبات الأعمال إلى وظائف واضحة وتكامل بين التطبيق والخادم.',
               'Builds application interfaces with Flutter and system services with Node.js. He helps translate business requirements into clear functionality and integrated app-to-server workflows.')},
]
for order, member in enumerate(members):
    file = out / 'images' / (member['id'] + '.jpg')
    with Image.open(source / member['source']) as original:
        photo = ImageOps.exif_transpose(original).convert('RGB')
        photo.thumbnail((1000, 1250), Image.Resampling.LANCZOS)
        photo.save(file, quality=92, optimize=True)
    data = file.read_bytes()
    member['order'] = order
    member['links'] = [{'url': 'https://wa.me/20' + member['phone'][1:],
                        'labelAr': 'واتساب: ' + member['phone'],
                        'labelEn': 'WhatsApp: ' + member['phone']}]
    member['media'] = {'file': file.relative_to(out).as_posix(),
                       'sha256': hashlib.sha256(data).hexdigest(), 'bytes': len(data),
                       'sourceSha256': hashlib.sha256((source / member['source']).read_bytes()).hexdigest(),
                       'alt': bi('صورة ' + member['name']['ar'], 'Portrait of ' + member['name']['en'])}
catalog = {'site': 'yogen', 'members': members}
(out / 'profiles.json').write_text(json.dumps(catalog, ensure_ascii=False, indent=2), encoding='utf-8')
cards = []
for m in members:
    cards.append('<article><img src="' + m['media']['file'] + '" alt="' + html.escape(m['media']['alt']['ar']) + '">' +
                 '<h2>' + html.escape(m['name']['ar']) + '</h2><p dir="ltr">' + html.escape(m['name']['en']) + '</p>' +
                 '<p>' + html.escape(m['role']['ar']) + '</p><p>' + html.escape(m['bio']['ar']) + '</p>' +
                 '<p dir="ltr">' + html.escape(m['role']['en']) + '</p><p dir="ltr">' + html.escape(m['bio']['en']) + '</p>' +
                 '<a href="' + m['links'][0]['url'] + '">' + html.escape(m['links'][0]['labelAr']) + '</a></article>')
(out / 'review.html').write_text('<!doctype html><html lang="ar" dir="rtl"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>YOGEN — فريق العمل</title><style>body{background:#0b1425;color:#e9eef9;font:16px/1.8 system-ui;margin:30px}main{display:flex;flex-wrap:wrap;gap:24px}article{width:300px;padding:20px;background:#142139;border-radius:20px}img{width:300px;height:300px;object-fit:cover;object-position:top;border-radius:16px}a{color:#67d5f6}</style><h1>فريق YOGEN</h1><main>' + ''.join(cards) + '</main></html>', encoding='utf-8')
print(json.dumps({'members': len(members), 'images': len(members), 'imageBytes': sum(m['media']['bytes'] for m in members)}))
