"""Process user uploaded screenshots for Alban El-Ra3y project and add to projects.json"""
import hashlib
import json
from pathlib import Path
from PIL import Image, ImageOps

root = Path(r"e:/Prog Progs/portfolio")
catalog_file = root / "content/company-projects/projects.json"
out_img_dir = root / "content/company-projects/images/alban-elra3y"
out_img_dir.mkdir(parents=True, exist_ok=True)

web_media_dir = root / "releases/company-projects/web/project-media"
web_media_dir.mkdir(parents=True, exist_ok=True)
local_web_media = root / "web/project-media"
local_web_media.mkdir(parents=True, exist_ok=True)
asset_img_dir = root / "assets/images/projects/alban-elra3y"
asset_img_dir.mkdir(parents=True, exist_ok=True)

inputs = [
    {
        "src": r"C:/Users/Graphic/.gemini/antigravity/brain/5541834c-354a-44a8-b4fb-6852354ae641/.user_uploaded/media_1791992176685_8e6d0cc5.png",
        "file": "cover.jpg",
        "alt_ar": "الواجهة الرئيسية لكتالوج ومنيو الراعي للألبان والمجمدات",
        "alt_en": "Main catalog and menu interface of Alban & Mogamadat El-Ra3y",
    },
    {
        "src": r"C:/Users/Graphic/.gemini/antigravity/brain/5541834c-354a-44a8-b4fb-6852354ae641/.user_uploaded/media_1791992193419_7cea7d90.png",
        "file": "gallery-01.jpg",
        "alt_ar": "تفاصيل المنتج وأسعار القطعة والكرتونة ومشاركة الرابط",
        "alt_en": "Product details page with multi-tier pricing and sharing options",
    },
    {
        "src": r"C:/Users/Graphic/.gemini/antigravity/brain/5541834c-354a-44a8-b4fb-6852354ae641/.user_uploaded/media_1791992230735_2f52fa69.png",
        "file": "gallery-02.jpg",
        "alt_ar": "لوحة تحكم وإدارة المنتجات والأقسام والعروض",
        "alt_en": "Admin dashboard for managing catalog products, categories and offers",
    },
]

media_entries = []
media_ids = []

for item in inputs:
    dest_file = out_img_dir / item["file"]
    with Image.open(item["src"]) as im:
        rgb = ImageOps.exif_transpose(im).convert("RGB")
        if max(rgb.size) > 1600:
            rgb.thumbnail((1600, 1000), Image.Resampling.LANCZOS)
        rgb.save(dest_file, quality=90, optimize=True)
    
    data = dest_file.read_bytes()
    sha = hashlib.sha256(data).hexdigest()
    media_id = f"m_{sha}"
    pub_url = f"https://portfolio-14d15.web.app/project-media/{sha}.jpg"
    
    # Save copy to web/project-media and assets
    (web_media_dir / f"{sha}.jpg").write_bytes(data)
    (local_web_media / f"{sha}.jpg").write_bytes(data)
    (asset_img_dir / item["file"]).write_bytes(data)
    
    media_entries.append({
        "file": f"images/alban-elra3y/{item['file']}",
        "alt": {
            "ar": item["alt_ar"],
            "en": item["alt_en"]
        },
        "sourceUrl": "https://alban-elra3y.web.app/",
        "sha256": sha,
        "bytes": len(data),
        "publishedAssetId": media_id,
        "publicUrl": pub_url
    })
    media_ids.append(media_id)

project_data = {
    "sourceId": "P016",
    "projectId": "yogen-p016",
    "sourceUrl": "https://alban-elra3y.web.app/",
    "content": {
        "title": {
            "ar": "الراعي — المنيو والكتالوج الإلكتروني الذكي",
            "en": "El-Ra3y — Smart Digital Menu & Catalog"
        },
        "summary": {
            "ar": "كتالوج إلكتروني متكامل وقائمة أسعار مباشرة للألبان والمجمدات والمواد الغذائية مع لوحة تحكم سحابية لإدارة المنتجات والتسعير والعروض ومشاركتها عبر واتساب وفيسبوك.",
            "en": "An integrated digital catalog and live price menu for dairy and frozen foods with a cloud management dashboard for products, multi-unit pricing, offers, and social sharing."
        },
        "body": {
            "ar": "المنيو والكتالوج الإلكتروني لمنتجات ألبان ومجمدات الراعي يقدم تجربة رقمية عصرية ومرنة تتيح للعملاء تصفح كافة منتجات المحل وأقسامه بأسعارها المحدثة لحظيًا. يدعم النظام تصنيفات المنتجات المتنوعة (الألبان، الأجبان، المجمدات، الصوصات، التوابل وغيرها)، والبحث الفوري، وعرض تفاصيل تسعير القطعة والعلبة والكرتونة والباركود، مع أزرار تواصل وطلب مباشر عبر واتساب وفيسبوك.\n\nيتضمن المشروع لوحة تحكم وإدارة سحابية متكاملة تتيح لصاحب العمل إضافة وتعديل المنتجات، والتحكم في الأسعار والعروض الترويجية، وإدارة الأقسام والتوفر، واستيراد وتصدير بيانات الكتالوج بكل سهولة وأمان.\n\n## الوظائف الأساسية\n- تصفح الكتالوج الإلكتروني وقوائم الأسعار المحدثة لحظيًا\n- فلاتر متقدمة للأقسام، المنتجات المخفضة، والبحث الذكي الفوري\n- عرض تفصيلي لأسعار القطعة والعلبة والكرتونة وتفاصيل العبوة\n- لوحة تحكم سحابية لإدارة المنتجات، الأقسام، وحالة النشر\n- واجهة مستجيبة بالكامل (PWA) مع دعم الوضع الداكن والتنقل السريع\n- مشاركة سريعة للمنتجات عبر واتساب وشبكات التواصل\n\n[زيارة موقع المشروع](https://alban-elra3y.web.app/)",
            "en": "The digital menu and smart catalog for El-Ra3y Dairy & Frozen Goods delivers a modern browsing experience for up-to-date products and real-time prices. It enables customers to explore diverse departments (dairy, cheese, frozen foods, sauces, spices), perform instant keyword searches, view multi-tier pricing (per piece, pack, carton) with barcode details, and order directly via WhatsApp and Facebook.\n\nThe project includes an intuitive cloud admin dashboard that empowers the merchant to create and edit products, configure prices and discounts, manage categories, track publication status, and import/export catalog data effortlessly.\n\n## Key features\n- Real-time digital catalog and updated product price lists\n- Advanced category filtering, discounted items view, and instant search\n- Multi-unit pricing (piece, pack, carton) and barcode display\n- Comprehensive cloud management dashboard for items and categories\n- Responsive modern UI (PWA) with dark mode and fast navigation\n- Quick product sharing via WhatsApp and social channels\n\n[Visit project website](https://alban-elra3y.web.app/)"
        },
        "contribution": {
            "ar": "تصميم وتطوير الكتالوج الإلكتروني الذكي، وواجهات تصفح المنتجات والأقسام، ولوحة إدارة المنتجات والتسعير السحابية.",
            "en": "Design and development of the smart digital catalog, product and department browsing interfaces, and cloud management dashboard."
        },
        "categoryId": "commerce",
        "slug": "alban-elra3y",
        "usage": "real",
        "attribution": "company",
        "mediaIds": media_ids,
        "links": [],
        "order": 15,
        "year": None
    },
    "media": media_entries,
    "editorial": {
        "externalUrl": "https://alban-elra3y.web.app/",
        "features": [
            {
                "ar": "تصفح الكتالوج وقوائم الأسعار المحدثة مباشرة",
                "en": "Live catalog and real-time price updates"
            },
            {
                "ar": "فلاتر الأقسام والبحث الفوري والمنتجات المخفضة",
                "en": "Category filters, instant search and discounted products"
            },
            {
                "ar": "تسعير متعدد الوحدات (قطعة، علبة، كرتونة) والباركود",
                "en": "Multi-tier pricing (piece, pack, carton) and barcode lookup"
            },
            {
                "ar": "لوحة تحكم وإدارة شاملة للمنتجات والأقسام",
                "en": "Full cloud management dashboard for products and sections"
            },
            {
                "ar": "مشاركة المنتجات والطلب عبر واتساب وفيسبوك",
                "en": "Product sharing and direct ordering via WhatsApp and Facebook"
            }
        ],
        "usageNote": "Active client digital catalog and store management system.",
        "attributionEvidence": "Developed by company.",
        "technologyNote": "Web, Firebase, PWA, Cloud Architecture.",
        "imageSelection": "Official catalog interface, product details view, and admin dashboard screenshots."
    }
}

catalog = json.loads(catalog_file.read_text(encoding="utf-8"))
# Check if project already exists, replace or append
existing_idx = next((i for i, p in enumerate(catalog["projects"]) if p.get("sourceId") == "P016" or p.get("projectId") == "yogen-p016"), None)
if existing_idx is not None:
    catalog["projects"][existing_idx] = project_data
else:
    catalog["projects"].append(project_data)

catalog_file.write_text(json.dumps(catalog, ensure_ascii=False, indent=2), encoding="utf-8")
print(json.dumps({"success": True, "projectId": project_data["projectId"], "images": len(media_entries)}))
